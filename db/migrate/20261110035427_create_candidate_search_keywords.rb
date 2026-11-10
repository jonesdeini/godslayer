# frozen_string_literal: true

class CreateCandidateSearchKeywords < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_search_keywords do |t|
      t.references :listing_candidate, null: false, foreign_key: true, index: false
      t.references :search_keyword, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :candidate_search_keywords, [ :listing_candidate_id, :search_keyword_id ],
      unique: true, name: "index_candidate_search_keywords_uniqueness"
  end
end
