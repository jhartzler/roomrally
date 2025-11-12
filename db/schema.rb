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

ActiveRecord::Schema[8.1].define(version: 2025_11_12_174536) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "room_id", null: false
    t.integer "score", default: 0, null: false
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_players_on_room_id"
    t.index ["session_id"], name: "index_players_on_session_id", unique: true
  end

  create_table "rooms", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "game_type", default: "Write And Vote"
    t.bigint "host_id"
    t.datetime "last_host_claim_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_rooms_on_code", unique: true
    t.index ["host_id"], name: "index_rooms_on_host_id"
  end

  add_foreign_key "players", "rooms"
  add_foreign_key "rooms", "players", column: "host_id"
end
