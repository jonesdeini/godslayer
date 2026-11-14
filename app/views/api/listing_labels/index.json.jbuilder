# frozen_string_literal: true

json.array! labels do |label|
  json.listing_id label.listing_id
  json.ebay_item_id label.listing.ebay_item_id
  json.title label.listing.title
  json.label label.label
  json.model label.model
  json.search_keyword_phrases label.listing.search_keywords.map(&:phrase)
end
