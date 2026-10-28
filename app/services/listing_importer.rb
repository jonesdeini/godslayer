# frozen_string_literal: true

class ListingImporter
  def self.import(raw_json, search_keyword_id:)
    new.import raw_json, search_keyword_id:
  end

  def import(raw_json, search_keyword_id:)
    raw = JSON.parse raw_json
    listing_id = write_listing raw
    ListingSearchKeywordWriter.write(listing_id:, search_keyword_id:)
    listing_id
  end

  private

  def write_listing(raw)
    ListingWriter.write(
      ebay_item_id: raw.fetch("itemId"),
      title: raw["title"],
      price_cents: price_cents(raw.dig("price", "value")),
      currency: raw.dig("price", "currency"),
      condition: raw["condition"],
      category_id: raw["categoryId"],
      seller: raw.dig("seller", "username"),
      postal_code: raw.dig("itemLocation", "postalCode"),
      country: raw.dig("itemLocation", "country"),
      url: raw["itemWebUrl"],
      raw:,
      seller_item_revision: raw["sellerItemRevision"]
    )
  end

  def price_cents(value)
    return 0 if value.nil?
    (BigDecimal(value) * 100).round.to_i
  end
end
