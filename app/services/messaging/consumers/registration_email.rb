module Messaging
  module Consumers
    class RegistrationEmail
      PREFETCH = 10   # max unacked messages in flight

      def run
        $stdout.sync = true
        @running = true
        %w[TERM INT].each { |signal| trap(signal) { @running = false } }

        connection = Broker.new_connection   # auto-recovery on: survives a broker restart
        channel    = connection.create_channel
        channel.prefetch(PREFETCH)
        queue      = Topology.declare!(channel)

        log(:info, "consumer_started", queue: Topology::CONFIRMATION_QUEUE)

        consumer = queue.subscribe(manual_ack: true) do |delivery_info, properties, payload|
          handle(channel, delivery_info, properties, payload)
        end

        sleep 0.5 while @running

        # Graceful stop (`docker compose stop`): an in-flight message that was
        # never acked is simply redelivered to the next consumer.
        consumer.cancel
        connection.close
        log(:info, "consumer_stopped")
      end

      private

      def handle(channel, delivery_info, properties, payload)
        tag        = delivery_info.delivery_tag
        request_id = properties.headers&.fetch("request_id", nil) || properties.message_id

        Rails.logger.tagged(request_id) do
          Rails.application.executor.wrap { process(JSON.parse(payload), request_id) }
          channel.ack(tag)
        rescue JSON::ParserError => e
          # A payload that can never parse is poison. Retrying changes nothing.
          log(:error, "message_unparseable", request_id: request_id, error: e.message)
          channel.reject(tag, false)
        rescue StandardError => e
          # First failure: put it back for one more try. Second: dead-letter it.
          retry_once = !delivery_info.redelivered?
          log(:error, "consumer_failed", request_id: request_id, error: e.class.name,
              message: e.message, action: retry_once ? "retry" : "dead_letter")
          channel.reject(tag, retry_once)
        end
      end

      def process(event, request_id)
        registration_id = event.dig("data", "registration_id")
        registration = Registration.includes(:user, ticket_type: :conference).find_by(id: registration_id)

        if registration.nil? || !registration.confirmed?
          log(:warn, "confirmation_skipped", request_id: request_id, registration_id: registration_id,
              reason: registration.nil? ? "not_found" : "status_#{registration.status}")
          return
        end

        if registration.confirmation_sent_at
          log(:info, "confirmation_already_sent", request_id: request_id, registration_id: registration.id)
          return
        end

        RegistrationMailer.confirmation(registration).deliver_now
        registration.update_column(:confirmation_sent_at, Time.current)
        log(:info, "confirmation_sent", request_id: request_id, registration_id: registration.id)
      end

      # Rake tasks log only to the file, so also print to stdout for
      # `docker compose logs rabbit_consumer`.
      def log(level, event, **fields)
        line = { event: event, level: level.to_s.upcase, time: Time.now.utc.iso8601(3), **fields }.to_json
        Rails.logger.public_send(level, line)
        $stdout.puts(line)
      end
    end
  end
end
