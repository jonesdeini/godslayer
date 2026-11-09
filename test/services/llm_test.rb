# frozen_string_literal: true

require "test_helper"

class LlmTest < ActiveSupport::TestCase
  test "classify_title_prompt includes the title and the single-word instruction" do
    prompt = Llm.classify_title_prompt "Dell R630 Server"

    assert_includes prompt, "Dell R630 Server"
    assert_includes prompt, "computer"
    assert_includes prompt, "part"
  end
end
