module Messaging
  module Consumers
    class RegistrationAnalytics
      GROUP_ID     = "confera-analytics".freeze
      MAX_ATTEMPTS = 3

      def run
        $stdout.sync = true
        @running = true
        %w[TERM INT].each { |signal| trap(signal) { @running = false } }

        consumer = KafkaClient.config(
          "group.id"                 => GROUP_ID,
          "client.id"                => "confera-analytics",
          "auto.offset.reset"        => "earliest",  # a brand-new group reads from the start of the log
          "enable.auto.offset.store" => false        # WE decide when a message counts as processed
        ).consumer

        consumer.subscribe(KafkaClient::REGISTRATIONS_TOPIC)
        log(:info, "consumer_started", group: GROUP_ID, topic: KafkaClient::REGISTRATIONS_TOPIC)

        while @running
          begin
            message = consumer.poll(1_000)   # wait up to 1s for a message
            next unless message

            process_with_retry(message)
            consumer.store_offset(message)   # mark done; librdkafka commits stored offsets in the background
          rescue Rdkafka::RdkafkaError => e
            log(:error, "kafka_error", error: e.message)
            sleep 1
          end
        end

        consumer.close   # commits stored offsets and leaves the group cleanly
        log(:info, "consumer_stopped")
      end

      private

      # Kafka has no "reject this one message". If we moved on without storing an
      # offset and then stored a LATER one, the failed message would be committed
      # past. So we retry the SAME message here, then give up on it deliberately.
      def process_with_retry(message)
        attempts = 0
        begin
          attempts += 1
          apply(message)
        rescue JSON::ParserError, KeyError, ArgumentError => e
          # Malformed payload: retrying can't fix it
          log(:error, "message_unparseable", partition: message.partition, offset: message.offset, error: e.message)
        rescue StandardError => e
          if attempts < MAX_ATTEMPTS
            log(:warn, "analytics_retry", partition: message.partition, offset: message.offset,
                attempt: attempts, error: e.class.name)
            sleep attempts
            retry
          end
          log(:error, "analytics_event_dropped", partition: message.partition, offset: message.offset,
              error: e.class.name, message: e.message)
        end
      end

      def apply(message)
        event          = JSON.parse(message.payload)
        event_id       = event.fetch("event_id")
        data           = event.fetch("data")
        conference_id  = data.fetch("conference_id")
        ticket_type_id = data.fetch("ticket_type_id")
        day            = Time.iso8601(event.fetch("occurred_at")).utc.to_date

        outcome = Rails.application.executor.wrap do
          ApplicationRecord.transaction do
            # INSERT ... ON CONFLICT DO NOTHING RETURNING id: no row back = counted before
            if ProcessedEvent.insert({ event_id: event_id }, unique_by: :event_id).rows.empty?
              :duplicate
            else
              increment_rollup(conference_id, ticket_type_id, day)
              :recorded
            end
          end
        end

        log(:info, outcome == :recorded ? "analytics_recorded" : "analytics_duplicate_skipped",
            event_id: event_id, partition: message.partition, offset: message.offset,
            request_id: event["request_id"])
      end

      def increment_rollup(conference_id, ticket_type_id, day)
        RegistrationRollup.upsert(
          { conference_id: conference_id, ticket_type_id: ticket_type_id, day: day, total: 1 },
          unique_by:    [ :ticket_type_id, :day ],
          on_duplicate: Arel.sql("total = registration_rollups.total + 1, updated_at = now()")
        )
      end

      # Rake tasks log only to the file, so also print to stdout for
      # `docker compose logs kafka_consumer`.
      def log(level, event, **fields)
        line = { event: event, level: level.to_s.upcase, time: Time.now.utc.iso8601(3), **fields }.to_json
        Rails.logger.public_send(level, line)
        $stdout.puts(line)
      end
    end
  end
end
