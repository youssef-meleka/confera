module Registrations
  class Create
    def self.call(...) = new(...).call

    def initialize(user:, ticket_types:, ticket_type_id:, request_id: nil)
      @user = user
      @ticket_types = ticket_types
      @ticket_type_id = ticket_type_id
      @request_id = request_id
    end

    def call
      result = nil

      Registration.transaction do
        result = attempt
        raise ActiveRecord::Rollback if result.failure?
      end

      # Published AFTER the transaction has committed. Publishing inside it
      # could announce a registration that later rolls back.
      publish_created(result.value) if result.success?
      result
    end

    private

    def publish_created(registration)
      Messaging::Publisher.publish(
        "registration.created",
        { registration_id: registration.id, user_id: registration.user_id,
          ticket_type_id: registration.ticket_type_id },
        request_id: @request_id
      )
    rescue StandardError => e
      # The registration IS committed. Raising here would reach the controller's
      # StandardError handler and return a 500 for a registration that exists.
      # Record the gap loudly; `rake events:replay_registrations` repairs it.
      Rails.logger.error({ event: "event_publish_failed", registration_id: registration.id,
                           request_id: @request_id, error: e.class.name, message: e.message }.to_json)
      Rails.error.report(e, handled: true)
    end

    def attempt
      ticket_type = @ticket_types.lock.find_by(id: @ticket_type_id)
      return Result.failure(Confera::RecordNotFound.new("Ticket type not found")) unless ticket_type

      return Result.failure(Confera::RegistrationClosed.new) unless ticket_type.conference.published?
      return Result.failure(Confera::CapacityExceeded.new) if ticket_type.registrations_count >= ticket_type.capacity

      registration = ticket_type.registrations.build(user: @user, status: :confirmed)

      if registration.save
        Result.success(registration)
      else
        Result.failure(Confera::ValidationFailed.new(registration))
      end
    end
  end
end