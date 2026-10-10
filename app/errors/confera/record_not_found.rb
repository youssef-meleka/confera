module Confera
  class RecordNotFound < Error
    def initialize(msg = "Record not found") = super
    def status = :not_found
  end
end
