module Api
  module V1
    class RegistrationsController < Api::V1::BaseController
      RESPONSE_INCLUDES = {
        ticket_type: { include: { conference: { only: [:id, :name] } } }
      }.freeze

      def index
        @registrations = Current.user.registrations
                                .includes(ticket_type: :conference)
                                .order(created_at: :desc)
        render json: @registrations, include: RESPONSE_INCLUDES
      end

      def create
        @registration = Registrations::Create.call(
          user: Current.user,
          ticket_type_id: registration_params[:ticket_type_id]
        ).value!

        render json: @registration, include: RESPONSE_INCLUDES, status: :created
      end

      private

      def registration_params
        params.require(:registration).permit(:ticket_type_id)
      end
    end
  end
end