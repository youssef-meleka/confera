class Track < ApplicationRecord
  belongs_to :conference, counter_cache: true
  has_many :talks, dependent: :destroy

  accepts_nested_attributes_for :talks,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs["title"].blank? }
end
