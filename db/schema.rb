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

ActiveRecord::Schema[8.1].define(version: 2025_12_23_214104) do
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
    t.integer "round", default: 1
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "write_and_vote_game_id"
    t.index ["prompt_id"], name: "index_prompt_instances_on_prompt_id"
    t.index ["write_and_vote_game_id"], name: "index_prompt_instances_on_write_and_vote_game_id"
  end

  create_table "prompt_packs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_type"
    t.boolean "is_default"
    t.string "name"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_prompt_packs_on_user_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", null: false
    t.bigint "prompt_pack_id"
    t.datetime "updated_at", null: false
    t.index ["prompt_pack_id"], name: "index_prompts_on_prompt_pack_id"
  end

  create_table "responses", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.bigint "prompt_instance_id", null: false
    t.text "rejection_reason"
    t.string "status", default: "submitted", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_responses_on_player_id"
    t.index ["prompt_instance_id"], name: "index_responses_on_prompt_instance_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.bigint "current_game_id"
    t.string "current_game_type"
    t.string "game_type", default: "Write And Vote"
    t.bigint "host_id"
    t.datetime "last_host_claim_at"
    t.bigint "prompt_pack_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["code"], name: "index_rooms_on_code", unique: true
    t.index ["current_game_type", "current_game_id"], name: "index_rooms_on_current_game"
    t.index ["host_id"], name: "index_rooms_on_host_id"
    t.index ["prompt_pack_id"], name: "index_rooms_on_prompt_pack_id"
    t.index ["user_id"], name: "index_rooms_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "image"
    t.string "name"
    t.string "password_digest"
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.bigint "response_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_votes_on_player_id"
    t.index ["response_id"], name: "index_votes_on_response_id"
  end

  create_table "write_and_vote_games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_prompt_index", default: 0
    t.bigint "prompt_pack_id"
    t.integer "round", default: 1
    t.datetime "round_ends_at"
    t.string "status"
    t.integer "timer_duration", default: 30
    t.boolean "timer_enabled", default: false, null: false
    t.integer "timer_increment", default: 60, null: false
    t.datetime "updated_at", null: false
    t.index ["prompt_pack_id"], name: "index_write_and_vote_games_on_prompt_pack_id"
  end

  add_foreign_key "players", "rooms"
  add_foreign_key "prompt_instances", "prompts"
  add_foreign_key "prompt_instances", "write_and_vote_games"
  add_foreign_key "prompt_packs", "users"
  add_foreign_key "prompts", "prompt_packs"
  add_foreign_key "responses", "players"
  add_foreign_key "responses", "prompt_instances"
  add_foreign_key "rooms", "players", column: "host_id"
  add_foreign_key "rooms", "prompt_packs"
  add_foreign_key "rooms", "users"
  add_foreign_key "votes", "players"
  add_foreign_key "votes", "responses"
  add_foreign_key "write_and_vote_games", "prompt_packs"
end
