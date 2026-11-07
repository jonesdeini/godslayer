# frozen_string_literal: true

require "test_helper"

class Llm::AnthropicClientTest < ActiveSupport::TestCase
  setup do
    ENV["ANTHROPIC_API_KEY"] = "fake-key"
  end

  teardown do
    ENV.delete "ANTHROPIC_API_KEY"
  end

  test "classifies a title, returning the model's single-word answer" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(headers: { "x-api-key" => "fake-key", "anthropic-version" => "2023-06-01" })
      .to_return(status: 200, body: { content: [ { type: "text", text: "computer" } ] }.to_json)

    assert_equal "computer", Llm::AnthropicClient.classify_title("Dell R630 Server 2x E5-2650v4")
  end
end
