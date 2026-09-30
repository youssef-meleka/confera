class CreateTicketTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_types do |t|
      t.references :conference, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price_cents, null: false, default: 0
      t.integer :capacity, null: false
      t.integer :registrations_count, default: 0, null: false

      t.timestamps
    end
  end
end
