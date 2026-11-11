# frozen_string_literal: true

module Llm
  class GeminiClient
    API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"
    MODEL = "gemini-3.1-flash-lite"
    RATE_LIMIT_DELAY_SECONDS = 4.5

    RequestError = Class.new StandardError

    def self.classify_title(title)
      new.classify_title title
    end

    def self.model
      MODEL
    end

    def initialize(rate_limit_delay_seconds: RATE_LIMIT_DELAY_SECONDS)
      @rate_limit_delay_seconds = rate_limit_delay_seconds
    end

    def classify_title(title)
      response = HTTP.timeout(30)
                      .headers("x-goog-api-key" => ENV.fetch("GEMINI_API_KEY"))
                      .post(format(API_URL, MODEL), json: {
                        contents: [ { parts: [ { text: Llm.classify_title_prompt(title) } ] } ]
                      })

      sleep @rate_limit_delay_seconds

      raise RequestError, "#{response.status}: #{response.body}" unless response.status.success?

      JSON.parse(response.body.to_s).dig("candidates", 0, "content", "parts", 0, "text").strip
    end
  end
end
