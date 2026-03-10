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

ActiveRecord::Schema[8.1].define(version: 2026_03_12_032828) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_generation_requests", force: :cascade do |t|
    t.boolean "counts_against_limit", default: true, null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.integer "pack_id", null: false
    t.string "pack_type", null: false
    t.jsonb "parsed_items"
    t.text "raw_response"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "user_theme", null: false
    t.index ["status"], name: "index_ai_generation_requests_on_status"
    t.index ["user_id", "created_at"], name: "index_ai_generation_requests_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_generation_requests_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "category_pack_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category_pack_id"], name: "index_categories_on_category_pack_id"
  end

  create_table "category_answers", force: :cascade do |t|
    t.boolean "alliterative", default: false
    t.string "body"
    t.bigint "category_instance_id", null: false
    t.datetime "created_at", null: false
    t.boolean "duplicate", default: false
    t.bigint "player_id", null: false
    t.integer "points_awarded", default: 0
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["category_instance_id"], name: "index_category_answers_on_category_instance_id"
    t.index ["player_id", "category_instance_id"], name: "index_category_answers_on_player_id_and_category_instance_id", unique: true
    t.index ["player_id"], name: "index_category_answers_on_player_id"
  end

  create_table "category_instances", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "category_list_game_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.integer "round", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_instances_on_category_id"
    t.index ["category_list_game_id"], name: "index_category_instances_on_category_list_game_id"
  end

  create_table "category_list_games", force: :cascade do |t|
    t.integer "categories_per_round", default: 6
    t.bigint "category_pack_id"
    t.datetime "created_at", null: false
    t.string "current_letter"
    t.integer "current_round", default: 1
    t.integer "reviewing_category_position", default: 0
    t.datetime "round_ends_at"
    t.boolean "show_instructions", default: true, null: false
    t.boolean "show_stage_scores", default: false, null: false
    t.string "status"
    t.integer "timer_duration"
    t.boolean "timer_enabled", default: false, null: false
    t.integer "timer_increment", default: 90, null: false
    t.integer "total_rounds", default: 3
    t.datetime "updated_at", null: false
    t.string "used_letters", default: [], array: true
    t.index ["category_pack_id"], name: "index_category_list_games_on_category_pack_id"
  end

  create_table "category_packs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_type", default: "Category List"
    t.boolean "is_default", default: false
    t.string "name"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_category_packs_on_user_id"
  end

  create_table "game_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_name", null: false
    t.bigint "eventable_id", null: false
    t.string "eventable_type", null: false
    t.jsonb "metadata", default: {}
    t.index [ "eventable_type", "eventable_id", "created_at" ], name: "index_game_events_on_eventable_and_created_at"
    t.index [ "eventable_type", "eventable_id" ], name: "index_game_events_on_eventable"
  end

  create_table "game_templates", force: :cascade do |t|
    t.bigint "category_pack_id"
    t.datetime "created_at", null: false
    t.string "game_type", null: false
    t.string "name", null: false
    t.bigint "prompt_pack_id"
    t.jsonb "settings", default: {}
    t.bigint "trivia_pack_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_pack_id"], name: "index_game_templates_on_category_pack_id"
    t.index ["prompt_pack_id"], name: "index_game_templates_on_prompt_pack_id"
    t.index ["trivia_pack_id"], name: "index_game_templates_on_trivia_pack_id"
    t.index ["user_id"], name: "index_game_templates_on_user_id"
  end

  create_table "hunt_packs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_type", default: "Scavenger Hunt"
    t.boolean "is_default", default: false, null: false
    t.string "name"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_hunt_packs_on_user_id"
  end

  create_table "hunt_prompt_instances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "hunt_prompt_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "scavenger_hunt_game_id", null: false
    t.datetime "updated_at", null: false
    t.integer "winner_submission_id"
    t.index ["hunt_prompt_id"], name: "index_hunt_prompt_instances_on_hunt_prompt_id"
    t.index ["scavenger_hunt_game_id"], name: "index_hunt_prompt_instances_on_scavenger_hunt_game_id"
  end

  create_table "hunt_prompts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "hunt_pack_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 5, null: false
    t.index ["hunt_pack_id"], name: "index_hunt_prompts_on_hunt_pack_id"
  end

  create_table "hunt_submissions", force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "favorite", default: false, null: false
    t.text "host_notes"
    t.bigint "hunt_prompt_instance_id", null: false
    t.boolean "late", default: false, null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["hunt_prompt_instance_id", "player_id"], name: "idx_hunt_submissions_prompt_player", unique: true
    t.index ["hunt_prompt_instance_id"], name: "index_hunt_submissions_on_hunt_prompt_instance_id"
    t.index ["player_id"], name: "index_hunt_submissions_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "room_id", null: false
    t.integer "score", default: 0, null: false
    t.string "session_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_players_on_room_id"
    t.index ["session_id", "room_id"], name: "index_players_on_session_id_and_room_id", unique: true
    t.index ["status"], name: "index_players_on_status"
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
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_responses_on_player_id"
    t.index ["prompt_instance_id"], name: "index_responses_on_prompt_instance_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.bigint "category_pack_id"
    t.string "code"
    t.datetime "created_at", null: false
    t.bigint "current_game_id"
    t.string "current_game_type"
    t.string "display_name"
    t.bigint "game_template_id"
    t.string "game_type", default: "Write And Vote"
    t.bigint "host_id"
    t.datetime "last_host_claim_at"
    t.bigint "prompt_pack_id"
    t.boolean "stage_only", default: false, null: false
    t.string "status"
    t.bigint "trivia_pack_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["category_pack_id"], name: "index_rooms_on_category_pack_id"
    t.index ["code"], name: "index_rooms_on_code", unique: true
    t.index ["current_game_type", "current_game_id"], name: "index_rooms_on_current_game"
    t.index ["game_template_id"], name: "index_rooms_on_game_template_id"
    t.index ["host_id"], name: "index_rooms_on_host_id"
    t.index ["prompt_pack_id"], name: "index_rooms_on_prompt_pack_id"
    t.index ["trivia_pack_id"], name: "index_rooms_on_trivia_pack_id"
    t.index ["user_id"], name: "index_rooms_on_user_id"
  end

  create_table "scavenger_hunt_games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "currently_showing_submission_id"
    t.bigint "hunt_pack_id"
    t.integer "round", default: 1, null: false
    t.datetime "round_ends_at"
    t.string "status"
    t.integer "timer_duration", default: 1800
    t.boolean "timer_enabled", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["hunt_pack_id"], name: "index_scavenger_hunt_games_on_hunt_pack_id"
  end

  create_table "score_tracker_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "room_id", null: false
    t.integer "score", default: 0
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_score_tracker_entries_on_room_id"
  end

  create_table "speed_trivia_games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_question_index", default: 0
    t.integer "reviewing_step", default: 1, null: false
    t.datetime "round_closed_at"
    t.datetime "round_ends_at"
    t.datetime "round_started_at"
    t.boolean "show_instructions", default: true, null: false
    t.string "status"
    t.integer "time_limit", default: 20
    t.integer "timer_duration"
    t.boolean "timer_enabled", default: false, null: false
    t.bigint "trivia_pack_id"
    t.datetime "updated_at", null: false
    t.index ["trivia_pack_id"], name: "index_speed_trivia_games_on_trivia_pack_id"
  end

  create_table "trivia_answers", force: :cascade do |t|
    t.boolean "correct"
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.integer "points_awarded", default: 0
    t.string "selected_option"
    t.datetime "submitted_at"
    t.bigint "trivia_question_instance_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "trivia_question_instance_id"], name: "index_trivia_answers_on_player_and_question_instance", unique: true
    t.index ["player_id"], name: "index_trivia_answers_on_player_id"
    t.index ["trivia_question_instance_id"], name: "index_trivia_answers_on_trivia_question_instance_id"
  end

  create_table "trivia_packs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_type", default: "Speed Trivia"
    t.boolean "is_default"
    t.string "name"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_trivia_packs_on_user_id"
  end

  create_table "trivia_question_instances", force: :cascade do |t|
    t.text "body"
    t.jsonb "correct_answers"
    t.datetime "created_at", null: false
    t.jsonb "options"
    t.integer "position"
    t.bigint "speed_trivia_game_id", null: false
    t.bigint "trivia_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["speed_trivia_game_id"], name: "index_trivia_question_instances_on_speed_trivia_game_id"
    t.index ["trivia_question_id"], name: "index_trivia_question_instances_on_trivia_question_id"
  end

  create_table "trivia_questions", force: :cascade do |t|
    t.text "body"
    t.jsonb "correct_answers"
    t.datetime "created_at", null: false
    t.jsonb "options"
    t.integer "position"
    t.bigint "trivia_pack_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trivia_pack_id"], name: "index_trivia_questions_on_trivia_pack_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "image"
    t.string "name"
    t.string "password_digest"
    t.string "plan", default: "free", null: false
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
    t.boolean "show_instructions", default: true, null: false
    t.string "status"
    t.integer "timer_duration", default: 30
    t.boolean "timer_enabled", default: false, null: false
    t.integer "timer_increment", default: 60, null: false
    t.datetime "updated_at", null: false
    t.index ["prompt_pack_id"], name: "index_write_and_vote_games_on_prompt_pack_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_generation_requests", "users"
  add_foreign_key "categories", "category_packs"
  add_foreign_key "category_answers", "category_instances"
  add_foreign_key "category_answers", "players"
  add_foreign_key "category_instances", "categories"
  add_foreign_key "category_instances", "category_list_games"
  add_foreign_key "category_list_games", "category_packs"
  add_foreign_key "category_packs", "users"
  add_foreign_key "game_templates", "category_packs", on_delete: :nullify
  add_foreign_key "game_templates", "prompt_packs", on_delete: :nullify
  add_foreign_key "game_templates", "trivia_packs", on_delete: :nullify
  add_foreign_key "game_templates", "users"
  add_foreign_key "hunt_packs", "users"
  add_foreign_key "hunt_prompt_instances", "hunt_prompts"
  add_foreign_key "hunt_prompt_instances", "scavenger_hunt_games"
  add_foreign_key "hunt_prompts", "hunt_packs"
  add_foreign_key "hunt_submissions", "hunt_prompt_instances"
  add_foreign_key "hunt_submissions", "players"
  add_foreign_key "players", "rooms"
  add_foreign_key "prompt_instances", "prompts"
  add_foreign_key "prompt_instances", "write_and_vote_games"
  add_foreign_key "prompt_packs", "users"
  add_foreign_key "prompts", "prompt_packs"
  add_foreign_key "responses", "players"
  add_foreign_key "responses", "prompt_instances"
  add_foreign_key "rooms", "category_packs"
  add_foreign_key "rooms", "game_templates", on_delete: :nullify
  add_foreign_key "rooms", "players", column: "host_id"
  add_foreign_key "rooms", "prompt_packs"
  add_foreign_key "rooms", "trivia_packs"
  add_foreign_key "rooms", "users"
  add_foreign_key "scavenger_hunt_games", "hunt_packs"
  add_foreign_key "score_tracker_entries", "rooms"
  add_foreign_key "speed_trivia_games", "trivia_packs"
  add_foreign_key "trivia_answers", "players"
  add_foreign_key "trivia_answers", "trivia_question_instances"
  add_foreign_key "trivia_packs", "users"
  add_foreign_key "trivia_question_instances", "speed_trivia_games"
  add_foreign_key "trivia_question_instances", "trivia_questions"
  add_foreign_key "trivia_questions", "trivia_packs"
  add_foreign_key "votes", "players"
  add_foreign_key "votes", "responses"
  add_foreign_key "write_and_vote_games", "prompt_packs"
end
