# frozen_string_literal: true

class CreateListingCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_candidates do |t|
      t.string   :ebay_item_id, null: false
      t.string   :title, null: false
      t.decimal  :price
      t.string   :condition
      t.jsonb    :raw_summary, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :detail_imported_at

      t.timestamps
    end

    add_index :listing_candidates, :ebay_item_id, unique: true
  end
end
