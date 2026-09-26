class CreateTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracks do |t|
      t.references :conference, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :talks_count, default: 0, null: false

      t.timestamps
    end
  end
end
