# frozen_string_literal: true

class KeywordSweepJob < ApplicationJob
  queue_as :default

  def perform(phrase)
    search_results = JSON.parse Ebay::Search.keyword(phrase)
    search_results.fetch("itemSummaries", []).each do |summary|
      import_item summary
    end
  end

  private

  # One bad item (a missing itemId, a failed fetch, an unparseable
  # response) shouldn't sink the rest of the sweep - the whole thing
  # happens inside this one rescue-protected method, not just the parts
  # after we already know the item id.
  def import_item(summary)
    item_id = summary.fetch "itemId"
    ListingImporter.import Ebay::Item.detail(item_id)
  rescue StandardError => e
    Rails.logger.error "KeywordSweepJob: failed to import #{summary.inspect}: #{e.class}: #{e.message}"
  end
end
