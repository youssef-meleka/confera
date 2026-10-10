module Confera
  class Conflict < Error
    def initialize(msg = "Resource conflict") = super
    def status = :conflict
  end
end
