module Confera
  class InternalError < Error
    def initialize(msg = "Internal server error") = super
  end
end
