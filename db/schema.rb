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

ActiveRecord::Schema[8.1].define(version: 2026_03_08_090004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "bot_dismissed", default: false
    t.boolean "bot_flagged", default: false
    t.jsonb "bot_reasons", default: []
    t.integer "bot_score", default: 0
    t.uuid "candidate_id", null: false
    t.uuid "company_id", null: false
    t.text "cover_letter"
    t.datetime "created_at", null: false
    t.uuid "current_interview_phase_id"
    t.datetime "form_loaded_at"
    t.boolean "honeypot_filled", default: false
    t.string "previous_status"
    t.string "rejection_reason"
    t.uuid "role_id", null: false
    t.string "status", default: "applied", null: false
    t.integer "submission_duration_ms"
    t.datetime "submitted_at"
    t.datetime "transferred_at"
    t.uuid "transferred_from_role_id"
    t.datetime "updated_at", null: false
    t.string "withdrawal_reason"
    t.index ["bot_flagged"], name: "idx_apps_bot_flagged"
    t.index ["candidate_id", "role_id"], name: "index_applications_on_candidate_id_and_role_id", unique: true
    t.index ["candidate_id"], name: "index_applications_on_candidate_id"
    t.index ["company_id", "status"], name: "index_applications_on_company_id_and_status"
    t.index ["company_id"], name: "index_applications_on_company_id"
    t.index ["current_interview_phase_id"], name: "idx_apps_current_phase"
    t.index ["role_id"], name: "index_applications_on_role_id"
  end

  create_table "candidates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["company_id", "email"], name: "index_candidates_on_company_id_and_email", unique: true
    t.index ["company_id"], name: "index_candidates_on_company_id"
    t.index ["email"], name: "index_candidates_on_email"
  end

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "primary_color", default: "#4F46E5"
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_companies_on_name"
    t.index ["subdomain"], name: "index_companies_on_subdomain", unique: true
  end

  create_table "custom_questions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "field_type", default: "text", null: false
    t.string "label", null: false
    t.jsonb "options", default: []
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.uuid "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_custom_questions_on_company_id"
    t.index ["role_id", "position"], name: "index_custom_questions_on_role_id_and_position"
    t.index ["role_id"], name: "index_custom_questions_on_role_id"
  end

  create_table "interview_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "interview_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["interview_id", "user_id"], name: "index_interview_participants_on_interview_and_user", unique: true
    t.index ["interview_id"], name: "index_interview_participants_on_interview_id"
    t.index ["user_id"], name: "index_interview_participants_on_user_id"
  end

  create_table "interview_phases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "original_phase_id"
    t.uuid "phase_owner_id"
    t.integer "phase_version", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.uuid "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_interview_phases_on_archived_at"
    t.index ["company_id"], name: "index_interview_phases_on_company_id"
    t.index ["original_phase_id"], name: "index_interview_phases_on_original_phase_id"
    t.index ["role_id", "name"], name: "index_interview_phases_active_unique_name", unique: true, where: "(archived_at IS NULL)"
    t.index ["role_id", "position"], name: "index_interview_phases_on_role_id_and_position"
    t.index ["role_id"], name: "index_interview_phases_on_role_id"
  end

  create_table "interviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "application_id", null: false
    t.datetime "cancelled_at"
    t.string "cancelled_reason"
    t.uuid "company_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "duration_minutes", default: 60
    t.uuid "interview_phase_id", null: false
    t.string "location"
    t.text "notes"
    t.integer "reschedule_count", default: 0, null: false
    t.string "reschedule_reason"
    t.jsonb "schedule_history", default: [], null: false
    t.datetime "scheduled_at"
    t.string "status", default: "unscheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "interview_phase_id"], name: "index_interviews_on_application_and_phase", unique: true
    t.index ["application_id"], name: "index_interviews_on_application_id"
    t.index ["company_id"], name: "index_interviews_on_company_id"
    t.index ["interview_phase_id"], name: "index_interviews_on_interview_phase_id"
    t.index ["status"], name: "idx_interviews_status"
  end

  create_table "offer_revisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "changed_by_id"
    t.datetime "created_at", null: false
    t.text "notes"
    t.uuid "offer_id", null: false
    t.integer "revision_number", null: false
    t.decimal "salary", precision: 12, scale: 2
    t.string "salary_currency"
    t.date "start_date"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_offer_revisions_on_changed_by_id"
    t.index ["offer_id"], name: "index_offer_revisions_on_offer_id"
  end

  create_table "offers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id", null: false
    t.text "notes"
    t.uuid "offer_application_id", null: false
    t.integer "revision", default: 1, null: false
    t.decimal "salary", precision: 12, scale: 2
    t.string "salary_currency", default: "USD"
    t.date "start_date"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_offers_on_company_id"
    t.index ["created_by_id"], name: "index_offers_on_created_by_id"
    t.index ["offer_application_id"], name: "idx_offers_on_app_id"
  end

  create_table "panel_interviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "interview_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["interview_id", "user_id"], name: "index_panel_interviews_on_interview_and_user", unique: true
    t.index ["interview_id"], name: "index_panel_interviews_on_interview_id"
    t.index ["user_id"], name: "index_panel_interviews_on_user_id"
  end

  create_table "question_snapshots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "answer"
    t.uuid "application_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "custom_question_id"
    t.string "field_type", null: false
    t.string "label", null: false
    t.jsonb "options", default: []
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "idx_question_snapshots_on_app_id"
    t.index ["company_id"], name: "index_question_snapshots_on_company_id"
    t.index ["custom_question_id"], name: "idx_question_snapshots_on_cq_id"
  end

  create_table "rate_limits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.datetime "window_start", null: false
    t.index ["key", "window_start"], name: "index_rate_limits_on_key_and_window_start", unique: true
  end

  create_table "role_status_transitions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "from_status", null: false
    t.uuid "role_id", null: false
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["company_id"], name: "index_role_status_transitions_on_company_id"
    t.index ["role_id", "created_at"], name: "idx_role_transitions_role_created"
    t.index ["role_id"], name: "index_role_status_transitions_on_role_id"
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "hiring_manager_id"
    t.string "location"
    t.string "preview_token"
    t.boolean "remote", default: false, null: false
    t.string "salary_currency", default: "USD"
    t.integer "salary_max"
    t.integer "salary_min"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "slug"], name: "index_roles_on_company_id_and_slug", unique: true
    t.index ["company_id", "status"], name: "index_roles_on_company_id_and_status"
    t.index ["company_id", "title"], name: "index_roles_on_company_id_and_title"
    t.index ["company_id"], name: "index_roles_on_company_id"
    t.index ["hiring_manager_id"], name: "index_roles_on_hiring_manager_id"
    t.index ["preview_token"], name: "index_roles_on_preview_token", unique: true, where: "(preview_token IS NOT NULL)"
  end

  create_table "scorecard_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "rating", null: false
    t.uuid "scorecard_id", null: false
    t.datetime "updated_at", null: false
    t.index ["scorecard_id", "name"], name: "index_scorecard_categories_on_scorecard_id_and_name", unique: true
    t.index ["scorecard_id"], name: "index_scorecard_categories_on_scorecard_id"
  end

  create_table "scorecards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "interview_id", null: false
    t.text "notes"
    t.boolean "submitted", default: false, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["company_id"], name: "index_scorecards_on_company_id"
    t.index ["interview_id", "user_id"], name: "index_scorecards_on_interview_id_and_user_id", unique: true
    t.index ["interview_id"], name: "index_scorecards_on_interview_id"
    t.index ["user_id"], name: "index_scorecards_on_user_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "admin_email", null: false
    t.string "company_name", null: false
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "primary_color", default: "#4F46E5"
    t.string "slug", null: false
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
  end

  create_table "transfer_markers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "candidate_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "source_role_id", null: false
    t.uuid "target_application_id"
    t.uuid "target_role_id", null: false
    t.datetime "transferred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_transfer_markers_on_candidate_id"
    t.index ["company_id"], name: "index_transfer_markers_on_company_id"
    t.index ["source_role_id", "candidate_id"], name: "index_transfer_markers_on_source_role_id_and_candidate_id"
    t.index ["source_role_id"], name: "index_transfer_markers_on_source_role_id"
    t.index ["target_role_id"], name: "index_transfer_markers_on_target_role_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "magic_link_token_digest"
    t.datetime "magic_link_token_sent_at"
    t.string "role", default: "interviewer", null: false
    t.string "time_zone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "role"], name: "index_users_on_company_id_and_role"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["magic_link_token_digest"], name: "index_users_on_magic_link_token_digest", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applications", "candidates", on_delete: :cascade
  add_foreign_key "applications", "companies", on_delete: :cascade
  add_foreign_key "applications", "roles", on_delete: :cascade
  add_foreign_key "candidates", "companies", on_delete: :cascade
  add_foreign_key "custom_questions", "companies"
  add_foreign_key "custom_questions", "roles"
  add_foreign_key "interview_participants", "interviews", on_delete: :cascade
  add_foreign_key "interview_participants", "users", on_delete: :cascade
  add_foreign_key "interview_phases", "companies"
  add_foreign_key "interview_phases", "interview_phases", column: "original_phase_id", on_delete: :nullify
  add_foreign_key "interview_phases", "roles"
  add_foreign_key "interviews", "applications", on_delete: :cascade
  add_foreign_key "interviews", "companies", on_delete: :cascade
  add_foreign_key "interviews", "interview_phases", on_delete: :cascade
  add_foreign_key "offer_revisions", "offers", on_delete: :cascade
  add_foreign_key "offer_revisions", "users", column: "changed_by_id"
  add_foreign_key "offers", "applications", column: "offer_application_id", on_delete: :cascade
  add_foreign_key "offers", "companies"
  add_foreign_key "offers", "users", column: "created_by_id"
  add_foreign_key "panel_interviews", "interviews", on_delete: :cascade
  add_foreign_key "panel_interviews", "users", on_delete: :cascade
  add_foreign_key "question_snapshots", "applications", on_delete: :cascade
  add_foreign_key "question_snapshots", "companies"
  add_foreign_key "question_snapshots", "custom_questions", on_delete: :nullify
  add_foreign_key "role_status_transitions", "companies"
  add_foreign_key "role_status_transitions", "roles", on_delete: :cascade
  add_foreign_key "role_status_transitions", "users", on_delete: :nullify
  add_foreign_key "roles", "companies"
  add_foreign_key "roles", "users", column: "hiring_manager_id"
  add_foreign_key "scorecard_categories", "scorecards", on_delete: :cascade
  add_foreign_key "scorecards", "companies"
  add_foreign_key "scorecards", "interviews", on_delete: :cascade
  add_foreign_key "scorecards", "users"
  add_foreign_key "transfer_markers", "applications", column: "target_application_id", on_delete: :nullify
  add_foreign_key "transfer_markers", "candidates"
  add_foreign_key "transfer_markers", "companies"
  add_foreign_key "transfer_markers", "roles", column: "source_role_id"
  add_foreign_key "transfer_markers", "roles", column: "target_role_id"
  add_foreign_key "users", "companies"
end
