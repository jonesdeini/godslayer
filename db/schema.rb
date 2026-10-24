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

ActiveRecord::Schema[8.1].define(version: 2026_10_24_061544) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "images", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.integer "position", null: false
    t.string "source_url", null: false
    t.string "local_path"
    t.string "sha256"
    t.datetime "downloaded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id", "position"], name: "index_images_on_listing_id_and_position", unique: true
    t.index ["listing_id"], name: "index_images_on_listing_id"
  end

  create_table "listings", force: :cascade do |t|
    t.string "ebay_item_id", null: false
    t.string "title", null: false
    t.integer "price_cents", null: false
    t.string "currency", default: "USD", null: false
    t.string "condition"
    t.string "category_id"
    t.string "seller"
    t.string "item_location"
    t.string "url", null: false
    t.jsonb "raw", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ebay_item_id"], name: "index_listings_on_ebay_item_id", unique: true
  end

  add_foreign_key "images", "listings", on_delete: :cascade
end
