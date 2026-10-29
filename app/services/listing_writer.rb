# frozen_string_literal: true

class ListingWriter
  def self.write(raw)
    ebay_item_id = raw.fetch "itemId"
    listing = Listing.find_or_initialize_by(ebay_item_id:)
    revised = !listing.new_record? && listing.seller_item_revision != raw["sellerItemRevision"]

    if listing.new_record? || revised
      listing.assign_attributes(
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
        seller_item_revision: raw["sellerItemRevision"],
        last_seen_at: Time.current
      )
      listing.first_seen_at ||= listing.last_seen_at
    end

    listing
  end

  def self.price_cents(value)
    return 0 if value.nil?
    (BigDecimal(value) * 100).round.to_i
  end
end
