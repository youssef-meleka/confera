# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_26_160217) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conferences", force: :cascade do |t|
    t.bigint "organizer_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "published", default: false, null: false
    t.integer "tracks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_id"], name: "index_conferences_on_organizer_id"
  end

  create_table "registrations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "ticket_type_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_type_id"], name: "index_registrations_on_ticket_type_id"
    t.index ["user_id", "ticket_type_id"], name: "index_registrations_on_user_id_and_ticket_type_id", unique: true
    t.index ["user_id"], name: "index_registrations_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "talks", force: :cascade do |t|
    t.bigint "track_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "speaker_name", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["track_id"], name: "index_talks_on_track_id"
  end

  create_table "ticket_types", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.string "name", null: false
    t.integer "price_cents", default: 0, null: false
    t.integer "capacity", null: false
    t.integer "registrations_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id"], name: "index_ticket_types_on_conference_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "talks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id"], name: "index_tracks_on_conference_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "conferences", "users", column: "organizer_id"
  add_foreign_key "registrations", "ticket_types"
  add_foreign_key "registrations", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "talks", "tracks"
  add_foreign_key "ticket_types", "conferences"
  add_foreign_key "tracks", "conferences"
end
