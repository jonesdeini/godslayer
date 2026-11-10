# frozen_string_literal: true

class CreateCandidateClassifications < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_classifications do |t|
      t.references :listing_candidate, null: false, foreign_key: true, index: false
      t.string  :verdict, null: false
      t.decimal :confidence
      t.string  :model_version
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :candidate_classifications, :listing_candidate_id, unique: true, where: "active"
  end
end
