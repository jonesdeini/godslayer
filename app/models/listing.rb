# frozen_string_literal: true

class Listing < ApplicationRecord
  has_many :listing_search_keywords, dependent: :destroy
  has_many :search_keywords, through: :listing_search_keywords
  has_many :listing_images, dependent: :destroy

  def self.from_ebay_json(ebay_json)
    ebay_item_id = ebay_json.fetch "itemId"
    buying_options = Array ebay_json["buyingOptions"]
    listing = find_or_initialize_by(ebay_item_id:)
    listing.assign_attributes(
      title: ebay_json["title"],
      price_cents: price_cents(ebay_json.dig("price", "value")),
      currency: ebay_json.dig("price", "currency"),
      condition: ebay_json["condition"],
      category_id: ebay_json["categoryId"],
      category_path: ebay_json["categoryPath"],
      seller: ebay_json.dig("seller", "username"),
      postal_code: ebay_json.dig("itemLocation", "postalCode"),
      country: ebay_json.dig("itemLocation", "country"),
      url: ebay_json["itemWebUrl"],
      raw: ebay_json,
      seller_item_revision: ebay_json["sellerItemRevision"],
      fixed_price: buying_options.include?("FIXED_PRICE"),
      auction: buying_options.include?("AUCTION"),
      best_offer: buying_options.include?("BEST_OFFER"),
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

  def description
    raw["description"]
  end

  def localized_aspects
    raw["localizedAspects"]
  end
end
