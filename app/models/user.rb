class User < ApplicationRecord
  
  has_secure_password

  has_many :organized_conferences, class_name: "Conference", foreign_key: "organizer_id", dependent: :destroy
  has_many :registrations, dependent: :destroy
  has_many :sessions, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
