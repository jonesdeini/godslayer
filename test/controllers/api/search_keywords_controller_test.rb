# frozen_string_literal: true

require "test_helper"

class Api::SearchKeywordsControllerTest < ActionDispatch::IntegrationTest
  test "returns active keywords" do
    get api_search_keywords_path

    assert_response :success
    body = JSON.parse response.body
    row = body.find { |r| r["id"] == search_keywords(:one).id }
    assert_equal search_keywords(:one).phrase, row["phrase"]
  end

  test "excludes deactivated keywords" do
    get api_search_keywords_path

    body = JSON.parse response.body
    assert_not_includes body.map { |r| r["id"] }, search_keywords(:retired).id
  end
end
