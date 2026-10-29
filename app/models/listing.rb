# frozen_string_literal: true

class Listing < ApplicationRecord
  has_many :listing_search_keywords, dependent: :destroy
  has_many :search_keywords, through: :listing_search_keywords

  def self.from_ebay_json(ebay_json)
    ebay_item_id = ebay_json.fetch "itemId"
    listing = find_or_initialize_by(ebay_item_id:)
    listing.assign_attributes(
      title: ebay_json["title"],
      price_cents: price_cents(ebay_json.dig("price", "value")),
      currency: ebay_json.dig("price", "currency"),
      condition: ebay_json["condition"],
      category_id: ebay_json["categoryId"],
      seller: ebay_json.dig("seller", "username"),
      postal_code: ebay_json.dig("itemLocation", "postalCode"),
      country: ebay_json.dig("itemLocation", "country"),
      url: ebay_json["itemWebUrl"],
      raw: ebay_json,
      seller_item_revision: ebay_json["sellerItemRevision"],
      last_seen_at: Time.current
    )
    listing.first_seen_at ||= listing.last_seen_at
    listing
  end

  def self.price_cents(value)
    return 0 if value.nil?
    (BigDecimal(value) * 100).round.to_i
  end
  private_class_method :price_cents

  def primary_image_url
    raw.dig "image", "imageUrl"
  end

  def additional_image_urls
    Array(raw["additionalImages"]).filter_map { |image| image["imageUrl"] }
  end
end
