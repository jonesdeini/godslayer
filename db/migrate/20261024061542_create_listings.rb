class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.string   :ebay_item_id, null: false
      t.string   :title, null: false
      t.integer  :price_cents, null: false
      t.string   :currency, null: false, default: "USD"
      t.string   :condition
      t.string   :category_id
      t.string   :seller
      t.string   :item_location
      t.string   :url, null: false
      t.jsonb    :raw, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :listings, :ebay_item_id, unique: true
  end
end
