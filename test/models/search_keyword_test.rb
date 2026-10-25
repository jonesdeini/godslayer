# frozen_string_literal: true

require "test_helper"

class SearchKeywordTest < ActiveSupport::TestCase
  test "requires a phrase" do
    refute SearchKeyword.new.valid?
  end

  test "phrase must be unique" do
    SearchKeyword.create! phrase: "totally unique test phrase"

    duplicate = SearchKeyword.new phrase: "totally unique test phrase"

    refute duplicate.valid?
  end
end
