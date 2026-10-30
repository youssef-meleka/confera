module Messaging
  class Publisher
    class PublishError < StandardError; end

    CONFIRM_TIMEOUT = 3 # seconds

    def self.publish(type, data, request_id: nil, event_id: SecureRandom.uuid)
      new.publish(type, data, request_id: request_id, event_id: event_id)
    end

    def publish(type, data, request_id: nil, event_id: SecureRandom.uuid)
      payload = Event.envelope(type, data, request_id: request_id, event_id: event_id).to_json

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
