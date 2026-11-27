# frozen_string_literal: true

require "test_helper"

class CandidatePromoterTest < ActiveSupport::TestCase
  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  def candidate_for(keyword)
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)
    CandidateSearchKeyword.create! listing_candidate_id: candidate.id, search_keyword_id: keyword.id
    candidate
  end

  test "fetches detail, imports it as a Listing, carries forward keywords, and links the candidate to it" do
    candidate = candidate_for search_keywords(:one)
    detail = { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
               itemWebUrl: "https://ebay.com/itm/111" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 200, body: detail

    CandidatePromoter.promote candidate

    listing = Listing.find_by ebay_item_id: "v1|111|0"
    assert listing.present?
    assert_equal [ search_keywords(:one) ], listing.search_keywords
    assert_equal listing, candidate.reload.listing
  end

  test "raises and leaves the candidate unlinked when the detail call fails" do
    candidate = candidate_for search_keywords(:one)
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 500, body: "boom"

    assert_raises(Ebay::Base::RequestError) { CandidatePromoter.promote candidate }

    assert_not Listing.exists?(ebay_item_id: "v1|111|0")
    assert_nil candidate.reload.listing_id
  end

  test "propagates QuotaExceededError the same as any other failure" do
    candidate = candidate_for search_keywords(:one)
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0")
      .to_return(status: 429, body: '{"errors":[{"errorId":2001,"message":"Too many requests."}]}')

    assert_raises(Ebay::Base::QuotaExceededError) { CandidatePromoter.promote candidate }

    assert_nil candidate.reload.listing_id
  end
end
