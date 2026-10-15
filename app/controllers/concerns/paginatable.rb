module Paginatable
  extend ActiveSupport::Concern

  included do
    include Pagy::Backend
  end

  private

  # Returns the page of records, sets the Link/Total-* headers, and
  # stores the data for the `meta` block in the response body.
  def paginate(scope)
    pagy, records = pagy(scope)
    pagy_headers_merge(pagy)

    @pagination = {
      page: pagy.page,
      per_page: pagy.limit,
      total: pagy.count,
      pages: pagy.pages,
      prev: pagy.prev,
      next: pagy.next
    }

    records
  end
end
