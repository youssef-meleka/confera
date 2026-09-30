class CreateRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"

      t.timestamps
    end
    add_index :registrations, [:user_id, :ticket_type_id], unique: true
  end
end
