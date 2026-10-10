module Confera
  class CapacityExceeded < Conflict
    def initialize(msg = "This ticket type is sold out") = super
  end
end
