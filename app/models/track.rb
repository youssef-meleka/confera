class Track < ApplicationRecord
  belongs_to :conference, counter_cache: true
  has_many :talks, dependent: :destroy
end
