module Confera
  class ValidationFailed < Error
    attr_reader :record

    def initialize(record)
      @record = record
      super("Validation failed")
    end

    def status  = :unprocessable_content
    def details = record.errors.to_hash(true)
  end
end
