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
      return Result.failure(:ticket_type_not_found, "Ticket type not found") unless ticket_type

      unless ticket_type.conference.published?
        return Result.failure(:conference_unpublished, "Conference is not open for registration")
      end

      if ticket_type.registrations_count >= ticket_type.capacity
        return Result.failure(:sold_out, "This ticket type is sold out")
      end

      registration = ticket_type.registrations.build(user: @user, status: :confirmed)

      if registration.save
        Result.success(registration)
      else
        Result.failure(:invalid, registration.errors.full_messages.to_sentence)
      end
    end
  end
end