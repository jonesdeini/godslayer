# frozen_string_literal: true

class ListingSearchKeywordWriter
  def self.write(listing_id:, search_keyword_id:)
    ListingSearchKeyword.upsert(
      { listing_id:, search_keyword_id: },
      unique_by: [ :listing_id, :search_keyword_id ]
    )
  end
end
