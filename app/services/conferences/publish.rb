module Conferences
  class Publish
    def self.call(...) = new(...).call

    def initialize(conference:)
      @conference = conference
    end

    def call
      return Result.success(@conference) if @conference.published?

      @conference.errors.add(:base, "needs at least one track") if @conference.tracks.empty?
      @conference.errors.add(:base, "needs at least one ticket type") if @conference.ticket_types.empty?
      return Result.failure(Confera::ValidationFailed.new(@conference)) if @conference.errors.any?

      @conference.update!(published: true)
      Result.success(@conference)
    end
  end
end
