module Messaging
  class KafkaPublisher
    # Fire-and-forget: produce only enqueues into a local buffer, so this never
    # blocks a request. Delivery failures surface later in the producer's callback.
    def self.publish(type, data, key:, request_id: nil, event_id: SecureRandom.uuid)
      payload = Event.envelope(type, data, request_id: request_id, event_id: event_id).to_json

      KafkaClient.producer.produce(
        topic:   KafkaClient::REGISTRATIONS_TOPIC,
        key:     key.to_s,               # same key → same partition → ordered
        payload: payload,
        headers: { "event_type" => type, "request_id" => request_id }.compact
      )

      event_id
    end
  end
end
