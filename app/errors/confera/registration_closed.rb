module Confera
  class RegistrationClosed < Error
    def initialize(msg = "Conference is not open for registration") = super
    def status = :unprocessable_content
  end
end
