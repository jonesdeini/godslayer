# frozen_string_literal: true

require "test_helper"

class Api::DeterminationsControllerTest < ActionDispatch::IntegrationTest
  def listing
    @listing ||= Listing.create!(
      ebay_item_id: "v1|determinations-controller-test|0",
      title: "Test Listing",
      price: 10.00,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/determinations-controller-test",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "creates a determination and returns it as JSON" do
    post api_listing_determinations_path(listing), params: {
      determination: { field: "ram", verdict: "mismatch", claimed_value: 16, claimed_unit: "GB",
                        photo_value: 32, photo_unit: "GB" }
    }

    assert_response :created
    body = JSON.parse response.body
    assert_equal "ram", body["field"]
    assert_equal "mismatch", body["verdict"]
    assert_equal true, body["active"]
  end

  test "renders a JSON 422 for an invalid verdict" do
    post api_listing_determinations_path(listing), params: { determination: { field: "ram", verdict: "nonsense" } }

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["error"].present?
  end

  test "renders a JSON 404 for an unknown listing" do
    post api_listing_determinations_path(999_999_999), params: { determination: { field: "ram", verdict: "match" } }

    assert_response :not_found
  end
end
