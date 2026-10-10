module Confera
  class Error < StandardError
    def status  = :internal_server_error
    def code    = self.class.name.demodulize.underscore
    def details = nil
  end
end
