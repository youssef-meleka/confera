module Messaging
  module KafkaClient
    REGISTRATIONS_TOPIC = "confera.registrations".freeze
    LOCK = Mutex.new

    def self.config(overrides = {})
      Rdkafka::Config.new({ "bootstrap.servers" => ENV.fetch("KAFKA_BROKERS") }.merge(overrides))
    end

    # One producer per process, created lazily (so after Puma forks workers).
    # rdkafka producers are thread-safe, unlike the Bunny channels in Broker.
    def self.producer
      LOCK.synchronize { @producer ||= build_producer }
    end

    def self.build_producer
      producer = config(
        "client.id"          => "confera-web",
        "enable.idempotence" => true,    # the producer's own retries can't duplicate or reorder
        "message.timeout.ms" => 10_000,  # drop a message nobody accepted within 10s
        "linger.ms"          => 5        # small batching window
      ).producer

      # Runs on rdkafka's background thread once the broker acks, or the message times out
      producer.delivery_callback = lambda do |report|
        next unless report.error
        Rails.logger.error({ event: "kafka_delivery_failed", partition: report.partition,
                             error: report.error.to_s }.to_json)
      end

      at_exit { shutdown }
      producer
    end

    def self.shutdown
      return unless @producer
      @producer.flush(5_000)   # let buffered messages out before the process exits
      @producer.close
    rescue StandardError
      nil
    end
  end
end
