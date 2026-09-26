class CreateTalks < ActiveRecord::Migration[8.1]
  def change
    create_table :talks do |t|
      t.references :track, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :speaker_name, null: false
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end
  end
end
