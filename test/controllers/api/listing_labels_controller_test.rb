# frozen_string_literal: true

require "test_helper"

class Api::ListingLabelsControllerTest < ActionDispatch::IntegrationTest
  def create_listing(ebay_item_id, title)
    Listing.create!(
      ebay_item_id:,
      title:,
      price: 10.00,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/#{ebay_item_id}",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "returns active labels with enough identifying info to trace back to the listing" do
    listing = create_listing "v1|label-api-test-1|0", "Dell R630 Server"
    ListingLabelWriter.write listing:, label: "computer", model: "claude-haiku-4-5-20251001"

    get api_listing_labels_path

    assert_response :success
    body = JSON.parse response.body
    assert_equal 1, body.size
    row = body.first
    assert_equal listing.id, row["listing_id"]
    assert_equal "v1|label-api-test-1|0", row["ebay_item_id"]
    assert_equal "Dell R630 Server", row["title"]
    assert_equal "computer", row["label"]
    assert_equal "claude-haiku-4-5-20251001", row["model"]
    assert_equal [], row["search_keyword_phrases"]
  end

  test "includes the phrases of every search keyword that ever matched the listing, active or not" do
    listing = create_listing "v1|label-api-test-4|0", "Dell PowerEdge R640 Server"
    ListingLabelWriter.write listing:, label: "computer", model: "claude-haiku-4-5-20251001"
    retired_keyword = SearchKeyword.create!(phrase: "r640", active: false)
    active_keyword = SearchKeyword.create!(phrase: '(r640,"r 640") (dell,poweredge)', active: true)
    listing.search_keywords << [retired_keyword, active_keyword]

    get api_listing_labels_path

    body = JSON.parse response.body
    assert_equal ["r640", '(r640,"r 640") (dell,poweredge)'], body.first["search_keyword_phrases"]
  end

  test "only includes the active label, not a deactivated prior one" do
    listing = create_listing "v1|label-api-test-2|0", "Relabeled Listing"
    ListingLabelWriter.write listing:, label: "part", model: "claude-haiku-4-5-20251001"
    ListingLabelWriter.write listing:, label: "computer", model: "claude-haiku-4-5-20251001"

    get api_listing_labels_path

    body = JSON.parse response.body
    assert_equal 1, body.size
    assert_equal "computer", body.first["label"]
  end

  test "excludes listings with no label at all" do
    create_listing "v1|label-api-test-3|0", "Unlabeled Listing"

    get api_listing_labels_path

    assert_equal [], JSON.parse(response.body)
  end
end
