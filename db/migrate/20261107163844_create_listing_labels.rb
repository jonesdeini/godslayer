# frozen_string_literal: true

class CreateListingLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_labels do |t|
      t.references :listing, null: false, foreign_key: true, index: false
      t.string :label, null: false
      t.string :model, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :listing_labels, :listing_id, unique: true, where: "active"
  end
end
