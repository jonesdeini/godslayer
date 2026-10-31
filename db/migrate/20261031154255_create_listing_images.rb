# frozen_string_literal: true

class CreateListingImages < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_images do |t|
      t.references :listing, null: false, foreign_key: true, index: false
      t.string :source_url, null: false

      t.timestamps
    end

    add_index :listing_images, [ :listing_id, :source_url ], unique: true
  end
end
