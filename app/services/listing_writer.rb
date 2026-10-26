# frozen_string_literal: true

class ListingWriter
  def self.write(ebay_item_id:, title:, price_cents:, currency:, condition:, category_id:, seller:, postal_code:, country:, url:, raw:)
    now = Time.current
    result = Listing.upsert(
      {
        ebay_item_id: ebay_item_id,
        title: title,
        price_cents: price_cents,
        currency: currency,
        condition: condition,
        category_id: category_id,
        seller: seller,
        postal_code: postal_code,
        country: country,
        url: url,
        raw: raw,
        first_seen_at: now,
        last_seen_at: now
      },
      unique_by: :ebay_item_id,
      update_only: [ :last_seen_at, :price_cents, :raw ]
    )
    result.first["id"]
  end
end
