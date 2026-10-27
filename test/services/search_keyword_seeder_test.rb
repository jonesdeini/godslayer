# frozen_string_literal: true

require "test_helper"

class SearchKeywordSeederTest < ActiveSupport::TestCase
  test "creates new keywords from the file" do
    with_seed_file [ { "phrase" => "totally fake test model", "exclude_phrase" => "placeholder exclude", "active" => true } ] do |path|
      SearchKeywordSeeder.seed path: path
    end

    keyword = SearchKeyword.find_by! phrase: "totally fake test model"
    assert_equal "placeholder exclude", keyword.exclude_phrase
    assert keyword.active?
  end

  test "updates exclude_phrase and active for an existing phrase" do
    existing = search_keywords :one

    with_seed_file [ { "phrase" => existing.phrase, "exclude_phrase" => "updated exclude", "active" => false } ] do |path|
      SearchKeywordSeeder.seed path: path
    end

    assert_equal "updated exclude", existing.reload.exclude_phrase
    assert_not existing.active?
  end

  test "deactivates an existing active keyword whose phrase is no longer in the file" do
    existing = search_keywords :one
    assert existing.active?

    with_seed_file [ { "phrase" => "some other phrase entirely" } ] do |path|
      SearchKeywordSeeder.seed path: path
    end

    assert_not existing.reload.active?
  end

  test "raises a clear error when the file doesn't exist" do
    error = assert_raises(RuntimeError) { SearchKeywordSeeder.seed path: Rails.root.join("tmp/does_not_exist.json") }

    assert_match "not found", error.message
  end

  private

  def with_seed_file(entries)
    file = Tempfile.new [ "search_terms", ".json" ]
    file.write entries.to_json
    file.flush

    yield Pathname.new(file.path)
  ensure
    file.close
    file.unlink
  end
end
