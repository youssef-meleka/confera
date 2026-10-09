module Api
  module V1
    class RegistrationsController < Api::V1::BaseController
      # Temporary mapping, replaced by the exception hierarchy in Module 8
      STATUS_FOR = {
        ticket_type_not_found: :not_found,
        conference_unpublished: :unprocessable_entity,
        sold_out: :conflict,
        invalid: :unprocessable_entity
      }.freeze

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
        result = Registrations::Create.call(
          user: Current.user,
          ticket_type_id: registration_params[:ticket_type_id]
        )

        if result.success?
          @registration = result.value
          render json: @registration, include: RESPONSE_INCLUDES, status: :created
        else
          render json: { error: result.error },
                 status: STATUS_FOR.fetch(result.error[:code], :unprocessable_entity)
        end
      end

      private

      def registration_params
        params.require(:registration).permit(:ticket_type_id)
      end
    end
  end
end