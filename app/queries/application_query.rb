class ApplicationQuery
  def self.call(...) = new(...).call

  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  private

  attr_reader :scope, :params

  # Query params can arrive as arrays/hashes (`?q[]=x`); only plain strings are valid.
  def string_param(key)
    value = params[key]
    return if value.blank?
    raise Confera::BadRequest, "#{key} must be a string" unless value.is_a?(String)

    value
  end

  # `sort=starts_at` ascending, `sort=-starts_at` descending.
  # The whitelist is the point: NEVER pass client input into `order`.
  def apply_sort(relation, allowed, default:)
    raw       = string_param(:sort) || default
    direction = raw.start_with?("-") ? :desc : :asc
    column    = allowed.fetch(raw.delete_prefix("-")) do
      raise Confera::BadRequest, "Invalid sort '#{raw}'. Allowed: #{allowed.keys.join(', ')}"
    end

    # `id` as a tiebreaker: OFFSET pagination over a non-unique sort key can
    # repeat or skip rows between pages, because ties may come back in any order.
    relation.order(column => direction, id: :asc)
  end

  def ilike(relation, columns, term)
    pattern    = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    conditions = columns.map { |c| "#{c} ILIKE :pattern" }.join(" OR ")
    relation.where(conditions, pattern: pattern)
  end

  def time_param(key)
    value = string_param(key)
    return if value.nil?

    Time.zone.parse(value) || invalid_time!(key)
  rescue ArgumentError
    invalid_time!(key)
  end

  def invalid_time!(key)
    raise Confera::BadRequest, "#{key} is not a valid date/time"
  end
end
