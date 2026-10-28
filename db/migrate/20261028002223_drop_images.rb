# frozen_string_literal: true

class DropImages < ActiveRecord::Migration[8.1]
  def change
    drop_table :images do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.integer  :position, null: false
      t.string   :source_url, null: false
      t.string   :local_path
      t.string   :sha256
      t.datetime :downloaded_at
      t.timestamps
      t.index [ :listing_id, :position ], unique: true
    end
  end
end
