class Session < ApplicationRecord
  belongs_to :user

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def expired?
    expires_at <= Time.current
  end
end
