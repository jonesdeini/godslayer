# frozen_string_literal: true

require "test_helper"

class SearchKeywordsControllerTest < ActionDispatch::IntegrationTest
  test "index lists keywords" do
    get search_keywords_path

    assert_response :success
    assert_select "td", text: search_keywords(:one).phrase
  end

  test "show renders a single keyword" do
    get search_keyword_path(search_keywords(:one))

    assert_response :success
  end

  test "new renders the form" do
    get new_search_keyword_path

    assert_response :success
  end

  test "create with a valid phrase redirects to the new keyword" do
    assert_difference "SearchKeyword.count", 1 do
      post search_keywords_path, params: { search_keyword: { phrase: "totally fake test model", exclude_phrase: "placeholder exclude", active: true } }
    end

    assert_redirected_to search_keyword_path(SearchKeyword.last)
  end

  test "create without a phrase re-renders the form" do
    assert_no_difference "SearchKeyword.count" do
      post search_keywords_path, params: { search_keyword: { phrase: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form" do
    get edit_search_keyword_path(search_keywords(:one))

    assert_response :success
  end

  test "update with valid params updates the keyword" do
    patch search_keyword_path(search_keywords(:one)), params: { search_keyword: { exclude_phrase: "placeholder exclude" } }

    assert_redirected_to search_keyword_path(search_keywords(:one))
    assert_equal "placeholder exclude", search_keywords(:one).reload.exclude_phrase
  end

  test "update with a blank phrase re-renders the form" do
    patch search_keyword_path(search_keywords(:one)), params: { search_keyword: { phrase: "" } }

    assert_response :unprocessable_entity
    assert_not_equal "", search_keywords(:one).reload.phrase
  end
end
