module Confera
  class NotAuthorized < Error
    def initialize(msg = "You are not allowed to perform this action") = super
    def status = :forbidden
  end
end
