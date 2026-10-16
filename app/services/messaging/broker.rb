module Messaging
  module Broker
    LOCK = Mutex.new

    # Publishing side: one shared connection per process. A Bunny CONNECTION is
    # thread-safe, a CHANNEL is not, so every publish borrows its own channel.
    def self.with_channel(&block)
      shared_connection.with_channel(&block)
    end

    # Consumers get their own connection (and use Bunny's auto-recovery).
    def self.new_connection(**opts)
      Bunny.new(ENV.fetch("RABBITMQ_URL"), **opts).tap(&:start)
    end

    def self.shared_connection
      LOCK.synchronize do
        @connection = nil unless @connection&.open?
        # Fail fast inside a web request, and no auto-recovery: we simply
        # build a new connection on the next publish.
        @connection ||= new_connection(connection_timeout: 2, automatically_recover: false)
      end
    end
  end
end
