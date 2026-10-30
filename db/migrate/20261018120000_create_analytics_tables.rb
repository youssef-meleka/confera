class CreateAnalyticsTables < ActiveRecord::Migration[8.1]
  def change
    # Read model written only by the Kafka consumer. No foreign keys on purpose:
    # analytics must keep working (and replaying) if a ticket type is later deleted.
    create_table :registration_rollups do |t|
      t.bigint  :conference_id,  null: false
      t.bigint  :ticket_type_id, null: false
      t.date    :day,            null: false
      t.integer :total,          null: false, default: 0
      t.timestamps
    end
    add_index :registration_rollups, [ :ticket_type_id, :day ], unique: true
    add_index :registration_rollups, [ :conference_id, :day ]

    # One row per event already counted. This is what makes the consumer idempotent.
    create_table :processed_events do |t|
      t.string :event_id, null: false
      t.timestamps
    end
    add_index :processed_events, :event_id, unique: true
  end
end
