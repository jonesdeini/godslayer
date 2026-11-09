# frozen_string_literal: true

module Llm
  class Client
    PROVIDERS = { "anthropic" => Llm::AnthropicClient, "gemini" => Llm::GeminiClient }.freeze

    def self.classify_title(title)
      provider.classify_title title
    end

    def self.model
      provider.model
    end

    def self.provider
      PROVIDERS.fetch ENV.fetch("LLM_PROVIDER", "gemini") do |unknown|
        raise ArgumentError, "Unknown LLM_PROVIDER: #{unknown}"
      end
    end
  end
end
