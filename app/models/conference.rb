class Conference < ApplicationRecord
  
  belongs_to :organizer, class_name: "User"

  has_many :tracks, dependent: :destroy
  has_many :ticket_types, dependent: :destroy
  has_many :talks, through: :tracks
  has_many :registrations, through: :ticket_types
end
