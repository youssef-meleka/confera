module Api
  module V1
    class TalksController < Api::V1::BaseController
      def index
        conference = policy_scope(Conference).find(params[:conference_id])
        scope = conference.talks.includes(:track)
        @talks = paginate(TalksQuery.call(scope, params))
        render json: {
          talks: @talks.as_json(include: { track: { only: [:id, :name] } }),
          meta: @pagination
        }
      end
    end
  end
end
