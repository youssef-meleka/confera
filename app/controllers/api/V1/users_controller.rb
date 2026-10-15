module Api
  module V1
    class UsersController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: [:create]
      skip_after_action :verify_authorized, :verify_policy_scoped

      def create
        @user = User.create!(user_params)
        render json: { id: @user.id, name: @user.name, email: @user.email }, status: :created
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end
    end
  end
end
