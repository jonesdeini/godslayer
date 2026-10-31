# frozen_string_literal: true

json.extract! listing, :id, :ebay_item_id, :title, :price_cents, :currency, :condition, :seller, :postal_code,
  :country, :url, :category_id, :category_path, :seller_item_revision, :fixed_price, :auction, :best_offer
json.description listing.description
json.localized_aspects listing.localized_aspects
json.images listing.listing_images do |listing_image|
  json.id listing_image.id
  json.url url_for(listing_image.file)
end
