# frozen_string_literal: true

class CreateListingSearchKeywords < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_search_keywords do |t|
      t.belongs_to :listing, null: false, foreign_key: true
      t.belongs_to :search_keyword, null: false, foreign_key: true
      t.timestamps
    end
    add_index :listing_search_keywords, [ :listing_id, :search_keyword_id ], unique: true
  end
end
