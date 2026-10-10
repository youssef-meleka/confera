module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_request!

      private

      def authenticate_request!
        session = session_from_bearer_token
        raise Confera::Unauthenticated, "Invalid or expired token" unless session

        Current.session = session
        session.touch(:last_used_at)
      end

      def session_from_bearer_token
        header = request.headers["Authorization"]
        return nil unless header&.start_with?("Bearer ")

        token = header.delete_prefix("Bearer ")
        session = Session.find_by(token_digest: Session.digest(token))
        session if session && !session.expired?
      end
    end
  end
end
