# frozen_string_literal: true

class ListingImporter
  def self.import(raw_json)
    new.import raw_json
  end

  def import(raw_json)
    raw = JSON.parse raw_json
    listing_id = write_listing raw
    write_images listing_id, raw
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
      item_location: item_location(raw["itemLocation"]),
      url: raw["itemWebUrl"],
      raw: raw
    )
  end

  def write_images(listing_id, raw)
    image_urls(raw).each_with_index do |url, position|
      ImageWriter.write listing_id: listing_id, position: position, source_url: url
    end
  end

  def image_urls(raw)
    urls = []
    primary = raw.dig "image", "imageUrl"
    urls << primary if primary
    Array(raw["additionalImages"]).each do |image|
      urls << image["imageUrl"] if image["imageUrl"]
    end
    urls
  end

  def price_cents(value)
    return 0 if value.nil?
    (BigDecimal(value) * 100).round.to_i
  end

  def item_location(item_location)
    return nil unless item_location
    [ item_location["city"], item_location["stateOrProvince"], item_location["country"] ].compact_blank.join ", "
  end
end
