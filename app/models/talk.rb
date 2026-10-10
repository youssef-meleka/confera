class Talk < ApplicationRecord
  belongs_to :track, counter_cache: true

  validates :title, :speaker_name, presence: true
end
