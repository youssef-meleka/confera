class Talk < ApplicationRecord
  belongs_to :track, counter_cache: true
end
