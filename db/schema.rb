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

ActiveRecord::Schema[8.1].define(version: 2025_11_19_031407) do
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

  create_table "prompt_instances", force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", null: false
    t.bigint "prompt_id", null: false
    t.bigint "room_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["prompt_id"], name: "index_prompt_instances_on_prompt_id"
    t.index ["room_id"], name: "index_prompt_instances_on_room_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "responses", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.bigint "prompt_instance_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_responses_on_player_id"
    t.index ["prompt_instance_id"], name: "index_responses_on_prompt_instance_id"
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
  add_foreign_key "prompt_instances", "prompts"
  add_foreign_key "prompt_instances", "rooms"
  add_foreign_key "responses", "players"
  add_foreign_key "responses", "prompt_instances"
  add_foreign_key "rooms", "players", column: "host_id"
end
