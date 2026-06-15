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

ActiveRecord::Schema[7.2].define(version: 2026_06_07_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "forwarding_number"
    t.datetime "onboarded_at"
    t.string "webhook_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["webhook_token"], name: "index_accounts_on_webhook_token", unique: true
  end

  create_table "call_logs", force: :cascade do |t|
    t.string "from"
    t.string "to"
    t.string "forwarded_to"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_call_logs_on_created_at"
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.string "signalwire_id", null: false
    t.string "e164", null: false
    t.string "friendly_name"
    t.string "area_code"
    t.string "webhook_url"
    t.datetime "webhook_synced_at"
    t.datetime "purchased_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["signalwire_id"], name: "index_phone_numbers_on_signalwire_id", unique: true
  end
end
