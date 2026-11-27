# frozen_string_literal: true

class ReplaceDetailImportedAtWithListingOnListingCandidates < ActiveRecord::Migration[8.1]
  def up
    add_reference :listing_candidates, :listing, foreign_key: true

    execute <<~SQL.squish
      UPDATE listing_candidates
      SET listing_id = listings.id
      FROM listings
      WHERE listing_candidates.ebay_item_id = listings.ebay_item_id
        AND listing_candidates.detail_imported_at IS NOT NULL
    SQL

    remove_column :listing_candidates, :detail_imported_at
  end

  def down
    add_column :listing_candidates, :detail_imported_at, :datetime

    execute <<~SQL.squish
      UPDATE listing_candidates
      SET detail_imported_at = updated_at
      WHERE listing_id IS NOT NULL
    SQL

    remove_reference :listing_candidates, :listing, foreign_key: true
  end
end
