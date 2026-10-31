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

ActiveRecord::Schema[8.1].define(version: 2026_10_31_154255) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "listing_images", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.string "source_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id", "source_url"], name: "index_listing_images_on_listing_id_and_source_url", unique: true
  end

  create_table "listing_search_keywords", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "search_keyword_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id", "search_keyword_id"], name: "idx_on_listing_id_search_keyword_id_3229ba5867", unique: true
    t.index ["listing_id"], name: "index_listing_search_keywords_on_listing_id"
    t.index ["search_keyword_id"], name: "index_listing_search_keywords_on_search_keyword_id"
  end

  create_table "listings", force: :cascade do |t|
    t.string "ebay_item_id", null: false
    t.string "title", null: false
    t.integer "price_cents", null: false
    t.string "currency", default: "USD", null: false
    t.string "condition"
    t.string "category_id"
    t.string "seller"
    t.string "url", null: false
    t.jsonb "raw", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "postal_code"
    t.string "country"
    t.string "seller_item_revision"
    t.string "category_path"
    t.boolean "fixed_price", default: false, null: false
    t.boolean "auction", default: false, null: false
    t.boolean "best_offer", default: false, null: false
    t.datetime "images_downloaded_at"
    t.datetime "published_at"
    t.index ["ebay_item_id"], name: "index_listings_on_ebay_item_id", unique: true
  end

  create_table "search_keywords", force: :cascade do |t|
    t.string "phrase", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "exclude_phrase"
    t.index ["phrase"], name: "index_search_keywords_on_phrase", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "listing_images", "listings"
  add_foreign_key "listing_search_keywords", "listings"
  add_foreign_key "listing_search_keywords", "search_keywords"
end
