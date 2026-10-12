module Api
  module V1
    class TalksController < Api::V1::BaseController
      def index
        conference = policy_scope(Conference).find(params[:conference_id])
        @talks = conference.talks.includes(:track).order(:starts_at)
        render json: @talks, include: { track: { only: [:id, :name] } }
      end
    end
  end
end
