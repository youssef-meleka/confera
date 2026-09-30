class TicketType < ApplicationRecord
  belongs_to :conference
  has_many :registrations, dependent: :destroy

  validates :capacity, numericality: { greater_than: 0 }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
end
