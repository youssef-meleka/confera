class Conference < ApplicationRecord
  
  belongs_to :organizer, class_name: "User"

  validates :name, presence: true

  has_many :tracks, dependent: :destroy
  has_many :ticket_types, dependent: :destroy
  has_many :talks, through: :tracks
  has_many :registrations, through: :ticket_types

  accepts_nested_attributes_for :tracks,
    allow_destroy: true,
    reject_if: :all_blank

  accepts_nested_attributes_for :ticket_types,
    allow_destroy: true,
    reject_if: :all_blank
end
