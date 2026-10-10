module Api
  module V1
    class ConferencesController < Api::V1::BaseController
      before_action :set_conference, only: [:show, :update, :destroy]
      before_action :authorize_organizer!, only: [:update, :destroy]

      RESPONSE_INCLUDES = {
        organizer: { only: [:id, :name] },
        tracks: { include: :talks },
        ticket_types: {}
      }.freeze

      def index
        @conferences = Conference.includes(:organizer, tracks: :talks, ticket_types: []).order(starts_at: :asc)
        render json: @conferences, include: RESPONSE_INCLUDES
      end

      def show
        render json: @conference, include: RESPONSE_INCLUDES
      end

      def create
        @conference = Current.user.organized_conferences.create!(conference_params)
        render json: @conference, include: RESPONSE_INCLUDES, status: :created
      end

      def update
        @conference.update!(conference_params)
        render json: @conference, include: RESPONSE_INCLUDES
      end

      def destroy
        @conference.destroy!
        head :no_content
      end

      private

      def set_conference
        # Eager-load for show/update to avoid N+1 on the nested tree
        @conference = Conference.includes(:organizer, tracks: :talks, ticket_types: []).find(params[:id])
      end

      # Temporary — replaced by ConferencePolicy in Module 9
      def authorize_organizer!
        raise Confera::NotAuthorized unless @conference.organizer_id == Current.user.id
      end

      def conference_params
        params.require(:conference).permit(
          :name, :description, :starts_at, :ends_at, :published,
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