# frozen_string_literal: true

require "test_helper"

class Api::ListingsControllerTest < ActionDispatch::IntegrationTest
  test "returns a listing as JSON, including attached image urls" do
    listing = Listing.create!(
      ebay_item_id: "v1|110591042924|0",
      title: "Test Laptop Computer 16GB RAM 512GB SSD",
      price_cents: 49999,
      currency: "USD",
      condition: "New",
      category_id: "177",
      category_path: "Computers/Tablets & Networking|Laptops & Netbooks|PC Laptops & Netbooks",
      seller: "testuser_developer514",
      postal_code: "95112",
      country: "US",
      url: "https://sandbox.ebay.com/itm/110591042924",
      seller_item_revision: "3",
      fixed_price: true,
      auction: false,
      best_offer: true,
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {
        "description" => "<p>A laptop.</p>",
        "localizedAspects" => [ { "type" => "STRING", "name" => "RAM Size", "value" => "16 GB" } ]
      }
    )
    primary = listing.listing_images.create! source_url: "https://images.example.com/primary.jpg"
    primary.file.attach io: StringIO.new("fake-primary-bytes"), filename: "primary.jpg", content_type: "image/jpeg"
    second = listing.listing_images.create! source_url: "https://images.example.com/second.jpg"
    second.file.attach io: StringIO.new("fake-second-bytes"), filename: "second.jpg", content_type: "image/jpeg"

    get api_listing_path(listing)

    assert_response :success
    body = JSON.parse response.body
    assert_equal "v1|110591042924|0", body["ebay_item_id"]
    assert_equal 49999, body["price_cents"]
    assert_equal 2, body["images"].size
    assert_equal listing.listing_images.map(&:id), body["images"].map { |image| image["id"] }
    body["images"].each { |image| assert_match %r{\Ahttp://[^/]+/rails/active_storage/blobs/}, image["url"] }
    assert_not_equal body["images"].first["url"], body["images"].second["url"]
    assert_equal "Computers/Tablets & Networking|Laptops & Netbooks|PC Laptops & Netbooks", body["category_path"]
    assert_equal "3", body["seller_item_revision"]
    assert_equal true, body["fixed_price"]
    assert_equal false, body["auction"]
    assert_equal true, body["best_offer"]
    assert_equal "<p>A laptop.</p>", body["description"]
    assert_equal [ { "type" => "STRING", "name" => "RAM Size", "value" => "16 GB" } ], body["localized_aspects"]
  end

  test "returns an empty images array when no images have been downloaded yet" do
    listing = Listing.create!(
      ebay_item_id: "v1|no-images|0",
      title: "No Images Yet",
      price_cents: 1000,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/no-images",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )

    get api_listing_path(listing)

    assert_response :success
    body = JSON.parse response.body
    assert_equal [], body["images"]
  end

  test "renders a JSON 404 for an unknown listing" do
    get api_listing_path(999_999_999)

    assert_response :not_found
    assert_equal "not found", JSON.parse(response.body)["error"]
  end

  test "renders a JSON 404 for a malformed id, instead of a 500" do
    get api_listing_path("not-a-number")

    assert_response :not_found
    assert_equal "not found", JSON.parse(response.body)["error"]
  end

  test "does not reject a non-browser client the way the HTML app would" do
    listing = Listing.create!(
      ebay_item_id: "v1|999|0",
      title: "Another Listing",
      price_cents: 1000,
      currency: "USD",
      condition: "New",
      category_id: "177",
      seller: "seller",
      postal_code: "95112",
      country: "US",
      url: "https://sandbox.ebay.com/itm/999",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )

    get api_listing_path(listing), headers: { "User-Agent" => "python-requests/2.31" }

    assert_response :success
  end
end
