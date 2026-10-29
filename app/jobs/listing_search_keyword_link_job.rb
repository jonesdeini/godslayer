# frozen_string_literal: true

class ListingSearchKeywordLinkJob < ApplicationJob
  queue_as :default

  def perform(ebay_item_id:, search_keyword_id:)
    listing = Listing.find_by!(ebay_item_id:)
    ListingSearchKeyword.find_or_create_by listing_id: listing.id, search_keyword_id:
  end
end
