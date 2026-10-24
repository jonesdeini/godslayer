# frozen_string_literal: true

class CreateImages < ActiveRecord::Migration[8.1]
  def change
    create_table :images do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.integer  :position, null: false
      t.string   :source_url, null: false
      t.string   :local_path
      t.string   :sha256
      t.datetime :downloaded_at
      t.timestamps
    end
    add_index :images, [ :listing_id, :position ], unique: true
  end
end
