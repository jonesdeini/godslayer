# frozen_string_literal: true

class KeywordSweepJob < ApplicationJob
  queue_as :sweep

  def perform(keyword)
    search_results = JSON.parse Ebay::Search.keyword(keyword.phrase, exclude_phrase: keyword.exclude_phrase)
    search_results.fetch("itemSummaries", []).each do |summary|
      import_item summary, keyword.id
    end
  end

  private

  # One bad item (a missing itemId, a failed fetch, an unparseable
  # response) shouldn't sink the rest of the sweep - the whole thing
  # happens inside this one rescue-protected method, not just the parts
  # after we already know the item id.
  def import_item(summary, search_keyword_id)
    item_id = summary.fetch "itemId"
    ListingSearchKeywordLinkJob.set(wait: 1.minute).perform_later search_keyword_id:, ebay_item_id: item_id

    listing = Listing.find_by ebay_item_id: item_id
    return if listing && !listing.changed_since_summary?(summary)

    ListingImporter.import Ebay::Item.detail(item_id)
  rescue StandardError => e
    Rails.logger.error "KeywordSweepJob: failed to import #{summary.inspect}: #{e.class}: #{e.message}"
  end
end
