module Confera
  class Unauthenticated < Error
    def initialize(msg = "Authentication required") = super
    def status = :unauthorized
  end
end
