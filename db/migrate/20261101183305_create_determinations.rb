# frozen_string_literal: true

class CreateDeterminations < ActiveRecord::Migration[8.1]
  def change
    create_table :determinations do |t|
      t.references :listing, null: false, foreign_key: true, index: false
      t.references :listing_image, foreign_key: true
      t.string :field, null: false
      t.string :verdict, null: false
      t.decimal :claimed_value
      t.string :claimed_unit
      t.decimal :photo_value
      t.string :photo_unit
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :determinations, [ :listing_id, :field ], unique: true, where: "active"
  end
end
