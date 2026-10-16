module Messaging
  module Topology
    EXCHANGE                = "confera.events".freeze
    DEAD_EXCHANGE           = "confera.events.dead".freeze
    CONFIRMATION_QUEUE      = "registration.confirmation_email".freeze
    CONFIRMATION_DEAD_QUEUE = "registration.confirmation_email.dead".freeze

    # Idempotent: declaring something that already exists with the same
    # arguments is a no-op. Called by publisher AND consumer, so messages
    # published before the consumer's first start are not dropped. It costs a
    # few round trips per publish, which is fine for a PoC. Production would
    # declare once at boot.
    #
    # Queue arguments can't change after creation: editing them later fails
    # with PRECONDITION_FAILED until the queue is deleted (RabbitMQ UI).
    def self.declare!(channel)
      events = channel.topic(EXCHANGE, durable: true)
      dead   = channel.fanout(DEAD_EXCHANGE, durable: true)

      channel.queue(CONFIRMATION_DEAD_QUEUE, durable: true).bind(dead)

      queue = channel.queue(CONFIRMATION_QUEUE, durable: true,
                            arguments: { "x-dead-letter-exchange" => DEAD_EXCHANGE })
      queue.bind(events, routing_key: "registration.created")
      queue
    end
  end
end
