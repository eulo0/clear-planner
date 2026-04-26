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

ActiveRecord::Schema[8.1].define(version: 2026_04_24_173000) do
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

  create_table "calendar_drafts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "operations", default: [], null: false
    t.jsonb "previous_operations", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_calendar_drafts_on_user_id"
  end

  create_table "course_items", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.datetime "due_at"
    t.integer "kind", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "due_at"], name: "index_course_items_on_course_id_and_due_at"
    t.index ["course_id"], name: "index_course_items_on_course_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "code"
    t.string "color", default: "#34D399", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes"
    t.date "end_date"
    t.time "end_time"
    t.time "ends_at"
    t.string "instructor"
    t.string "location"
    t.string "meeting_days"
    t.string "office"
    t.text "office_hours"
    t.string "professor"
    t.bigint "project_id"
    t.boolean "recurring", default: false, null: false
    t.integer "repeat_days", default: [], null: false, array: true
    t.date "repeat_until"
    t.date "start_date"
    t.time "start_time"
    t.time "starts_at"
    t.string "term"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_courses_on_project_id"
    t.index ["user_id", "repeat_until"], name: "index_courses_on_user_id_and_repeat_until"
    t.index ["user_id", "start_date"], name: "index_courses_on_user_id_and_start_date"
    t.index ["user_id"], name: "index_courses_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "event_exceptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.date "excluded_date", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "excluded_date"], name: "index_event_exceptions_on_event_id_and_excluded_date", unique: true
    t.index ["event_id"], name: "index_event_exceptions_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.boolean "all_day", default: false, null: false
    t.string "color", default: "#34D399", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes"
    t.datetime "ends_at"
    t.string "location"
    t.integer "priority"
    t.bigint "project_id"
    t.boolean "recurring", default: false, null: false
    t.integer "repeat_days", default: [], null: false, array: true
    t.date "repeat_until"
    t.datetime "starts_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_events_on_project_id"
    t.index ["user_id", "repeat_until"], name: "index_events_on_user_id_and_repeat_until"
    t.index ["user_id", "starts_at"], name: "index_events_on_user_id_and_starts_at"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "message"
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.datetime "read_at"
    t.datetime "scheduled_for"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notifiable_type", "notifiable_id", "category", "scheduled_for"], name: "idx_notifications_reminder_dedup", unique: true, where: "(scheduled_for IS NOT NULL)"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "project_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "project_id", null: false
    t.bigint "sender_id", null: false
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_invitations_on_project_id"
    t.index ["sender_id"], name: "index_project_invitations_on_sender_id"
    t.index ["token"], name: "index_project_invitations_on_token", unique: true
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "project_messages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_project_messages_on_project_id"
    t.index ["user_id"], name: "index_project_messages_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "invite_token"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", default: "default", null: false
    t.string "timezone", default: "american/chicago", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "week_starts_on", default: 1, null: false
    t.index ["user_id", "name"], name: "index_schedules_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_schedules_on_user_id"
  end

  create_table "syllabuses", force: :cascade do |t|
    t.jsonb "course_draft"
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.text "parse_error"
    t.string "parse_status"
    t.datetime "parsed_at"
    t.text "parsed_text"
    t.string "title", null: false
    t.bigint "user_id", null: false
    t.index ["course_id"], name: "index_syllabuses_on_course_id"
    t.index ["user_id"], name: "index_syllabuses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_created_at"
    t.integer "invitation_limit"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.integer "invitations_count", default: 0
    t.bigint "invited_by_id"
    t.string "invited_by_type"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "theme", default: "green", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["username"], name: "index_users_on_username"
  end

  create_table "work_shifts", force: :cascade do |t|
    t.string "color", default: "#34D399", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes"
    t.time "end_time"
    t.string "location"
    t.boolean "recurring", default: true, null: false
    t.string "repeat_days", default: [], null: false, array: true
    t.date "repeat_until"
    t.date "start_date"
    t.time "start_time"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_work_shifts_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calendar_drafts", "users"
  add_foreign_key "course_items", "courses"
  add_foreign_key "courses", "projects"
  add_foreign_key "courses", "users"
  add_foreign_key "documents", "users"
  add_foreign_key "event_exceptions", "events"
  add_foreign_key "events", "projects"
  add_foreign_key "events", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "project_invitations", "projects"
  add_foreign_key "project_invitations", "users", column: "sender_id"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "project_messages", "projects"
  add_foreign_key "project_messages", "users"
  add_foreign_key "schedules", "users"
  add_foreign_key "syllabuses", "courses", on_delete: :nullify
  add_foreign_key "syllabuses", "users"
  add_foreign_key "work_shifts", "users"
end
