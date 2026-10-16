module Messaging
  class Publisher
    class PublishError < StandardError; end

    CONFIRM_TIMEOUT = 3 # seconds

    def self.publish(type, data, request_id: nil)
      new.publish(type, data, request_id: request_id)
    end

    def publish(type, data, request_id: nil)
      event_id = SecureRandom.uuid
      payload = {
        event_id:    event_id,
        type:        type,
        occurred_at: Time.current.utc.iso8601(3),
        request_id:  request_id,
        data:        data          # IDs only. The consumer reloads fresh state from the DB
      }.to_json

      Timeout.timeout(CONFIRM_TIMEOUT) do
        Broker.with_channel do |channel|
          channel.confirm_select
          Topology.declare!(channel)

          channel.topic(Topology::EXCHANGE, durable: true).publish(
            payload,
            routing_key:  type,
            persistent:   true,
            message_id:   event_id,
            type:         type,
            content_type: "application/json",
            headers:      { "request_id" => request_id }.compact
          )

          channel.wait_for_confirms or raise PublishError, "broker did not confirm the message"
        end
      end

      event_id
    end
  end
end
