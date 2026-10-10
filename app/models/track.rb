class Track < ApplicationRecord
  belongs_to :conference, counter_cache: true
  has_many :talks, dependent: :destroy

  validates :name, presence: true

  accepts_nested_attributes_for :talks,
    allow_destroy: true,
    reject_if: :all_blank
end
