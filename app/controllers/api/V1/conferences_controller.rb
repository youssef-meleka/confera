module Api
  module V1
    class ConferencesController < Api::V1::BaseController
      before_action :set_conference, only: [:show, :update, :destroy, :publish]

      RESPONSE_INCLUDES = {
        organizer: { only: [:id, :name] },
        tracks: { include: :talks },
        ticket_types: {}
      }.freeze

      def index
        @conferences = policy_scope(Conference).includes(:organizer, tracks: :talks, ticket_types: []).order(starts_at: :asc)
        render json: @conferences, include: RESPONSE_INCLUDES
      end

      def show
        authorize @conference
        render json: @conference, include: RESPONSE_INCLUDES
      end

      def create
        @conference = Current.user.organized_conferences.new(conference_params)
        authorize @conference
        @conference.save!
        render json: @conference, include: RESPONSE_INCLUDES, status: :created
      end

      def update
        authorize @conference
        @conference.update!(conference_params)
        render json: @conference, include: RESPONSE_INCLUDES
      end

      def destroy
        authorize @conference
        @conference.destroy!
        head :no_content
      end

      def publish
        authorize @conference
        @conference = Conferences::Publish.call(conference: @conference).value!
        render json: @conference, include: RESPONSE_INCLUDES
      end

      private

      def set_conference
        # Eager-load for show/update to avoid N+1 on the nested tree
        @conference = policy_scope(Conference).includes(:organizer, tracks: :talks, ticket_types: []).find(params[:id])
      end

      def conference_params
        params.require(:conference).permit(
          :name, :description, :starts_at, :ends_at,
          tracks_attributes: [
            :id, :name, :description, :_destroy,
            talks_attributes: [:id, :title, :description, :speaker_name, :starts_at, :ends_at, :_destroy]
          ],
          ticket_types_attributes: [:id, :name, :price_cents, :capacity, :_destroy]
        )
      end
    end
  end
end