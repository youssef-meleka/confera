module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate_request!

      after_action :verify_authorized,    except: :index
      after_action :verify_policy_scoped, only: :index

      private

      # Pundit calls `current_user` by default; we have Current.user
      def pundit_user = Current.user

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
