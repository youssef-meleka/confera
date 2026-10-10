module Confera
  class BadRequest < Error
    def initialize(msg = "Bad request") = super
    def status = :bad_request
  end
end
