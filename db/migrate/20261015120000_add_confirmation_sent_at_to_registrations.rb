class AddConfirmationSentAtToRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :registrations, :confirmation_sent_at, :datetime
  end
end
