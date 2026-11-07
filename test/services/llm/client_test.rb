# frozen_string_literal: true

require "test_helper"

class Llm::ClientTest < ActiveSupport::TestCase
  teardown do
    ENV.delete "LLM_PROVIDER"
  end

  test "defaults to the anthropic provider" do
    assert_equal Llm::AnthropicClient, Llm::Client.provider
  end

  test "raises for an unconfigured provider" do
    ENV["LLM_PROVIDER"] = "openai"

    assert_raises(ArgumentError) { Llm::Client.provider }
  end
end
