module Api
  module V1
    class UsersController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: [:create]

      def create
        @user = User.new(user_params)

        if @user.save
          render json: { id: @user.id, name: @user.name, email: @user.email }, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end
    end
  end
end
