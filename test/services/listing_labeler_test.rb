# frozen_string_literal: true

require "test_helper"

class ListingLabelerTest < ActiveSupport::TestCase
  def create_listing(ebay_item_id)
    Listing.create!(
      ebay_item_id:,
      title: "Test Listing #{ebay_item_id}",
      price: 10.00,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/#{ebay_item_id}",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  setup do
    ENV["LLM_PROVIDER"] = "anthropic"
    ENV["ANTHROPIC_API_KEY"] = "fake-key"
  end

  teardown do
    ENV.delete "ANTHROPIC_API_KEY"
  end

  def stub_classification(verdict)
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: { content: [ { type: "text", text: verdict } ] }.to_json)
  end

  test "labels unlabeled listings up to the limit" do
    stub_classification "computer"
    listing = create_listing "v1|labeler-test-1|0"
    already_labeled = create_listing "v1|labeler-test-2|0"
    ListingLabelWriter.write listing: already_labeled, label: "part", model: "claude-haiku-4-5-20251001"

    ListingLabeler.label_all limit: 10

    assert_equal "computer", listing.reload.active_label.label
    assert_equal "part", already_labeled.reload.active_label.label
    assert_requested :post, "https://api.anthropic.com/v1/messages", times: 1
  end

  test "force relabels listings that already have a label" do
    stub_classification "part"
    listing = create_listing "v1|labeler-test-3|0"
    ListingLabelWriter.write listing:, label: "computer", model: "claude-haiku-4-5-20251001"

    ListingLabeler.label_all limit: 10, force: true

    assert_equal "part", listing.reload.active_label.label
  end

  test "a failure for one listing does not stop the rest" do
    listing = create_listing "v1|labeler-test-4|0"
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_timeout

    assert_nothing_raised { ListingLabeler.label_all limit: 10 }
    assert_nil listing.reload.active_label
  end
end
