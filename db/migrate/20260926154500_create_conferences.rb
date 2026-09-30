class CreateConferences < ActiveRecord::Migration[8.1]
  def change
    create_table :conferences do |t|
      t.references :organizer, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :published, default: false, null: false
      t.integer :tracks_count, default: 0, null: false

      t.timestamps
    end
  end
end
