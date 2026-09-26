class Registration < ApplicationRecord
  belongs_to :user
  belongs_to :ticket_type, counter_cache: true

  enum :status, { pending: "pending", confirmed: "confirmed", cancelled: "cancelled" }

end
