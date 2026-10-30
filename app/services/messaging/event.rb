module Messaging
  module Event
    def self.envelope(type, data, request_id: nil, event_id: SecureRandom.uuid)
      {
        event_id:    event_id,
        type:        type,
        occurred_at: Time.current.utc.iso8601(3),
        request_id:  request_id,
        data:        data          # IDs only. Consumers derive everything else themselves
      }
    end
  end
end
