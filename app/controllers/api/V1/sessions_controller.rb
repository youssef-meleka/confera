module Api
  module V1
    class SessionsController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: [:create]

      def create
        user = User.find_by(email: params[:email])

        raise Confera::Unauthenticated, "Invalid email or password" unless user&.authenticate(params[:password])

        token = SecureRandom.hex(32)
        session = user.sessions.create!(token_digest: Session.digest(token), expires_at: 2.weeks.from_now)

        render json: { token: token, expires_at: session.expires_at }, status: :created
      end

      def destroy
        Current.session.destroy
        head :no_content
      end
    end
  end
end
