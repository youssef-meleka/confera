module Registrations
  class Create
    def self.call(...) = new(...).call

    def initialize(user:, ticket_type_id:)
      @user = user
      @ticket_type_id = ticket_type_id
    end

    def call
      result = nil

      Registration.transaction do
        result = attempt
        raise ActiveRecord::Rollback if result.failure?
      end

      # Module 13: publish `registration.created` HERE, after the transaction
      # has committed. Publishing inside it could announce a registration
      # that later rolls back.
      result
    end

    private

    def attempt
      ticket_type = TicketType.lock.find_by(id: @ticket_type_id)
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