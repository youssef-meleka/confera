class TalksQuery < ApplicationQuery
  SORTS = {
    "starts_at" => :starts_at,
    "title"     => :title
  }.freeze

  def call
    relation = scope

    relation = relation.where(track_id: string_param(:track_id)) if string_param(:track_id)
    relation = ilike(relation, %w[talks.title talks.speaker_name], string_param(:q)) if string_param(:q)

    apply_sort(relation, SORTS, default: "starts_at")
  end
end
