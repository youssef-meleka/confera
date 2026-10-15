class ConferencesQuery < ApplicationQuery
  SORTS = {
    "starts_at"  => :starts_at,
    "name"       => :name,
    "created_at" => :created_at
  }.freeze

  def call
    relation = scope

    relation = relation.where(organizer_id: string_param(:organizer_id)) if string_param(:organizer_id)
    relation = ilike(relation, %w[conferences.name], string_param(:q))   if string_param(:q)

    after  = time_param(:starts_after)
    before = time_param(:starts_before)
    relation = relation.where(starts_at: after..)  if after
    relation = relation.where(starts_at: ..before) if before

    apply_sort(relation, SORTS, default: "starts_at")
  end
end
