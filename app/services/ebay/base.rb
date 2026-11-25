# frozen_string_literal: true

module Ebay
  class Base
    API_HOSTS = { "sandbox" => "api.sandbox.ebay.com", "production" => "api.ebay.com" }.freeze

    RequestError = Class.new StandardError
    QuotaExceededError = Class.new RequestError

    def self.api_host
      API_HOSTS.fetch Rails.application.config.x.ebay.environment
    end

    private

    def get(path)
      response = HTTP.timeout(30)
                      .auth("Bearer #{Ebay::Authenticator.token}")
                      .headers("X-EBAY-C-MARKETPLACE-ID" => Rails.application.config.x.ebay.marketplace_id)
                      .get(path)

      raise QuotaExceededError, "#{response.status}: #{response.body}" if response.status.code == 429
      raise RequestError, "#{response.status}: #{response.body}" unless response.status.success?

      response.body.to_s
    end

    def base_url
      "https://#{self.class.api_host}/buy/browse/v1"
    end
  end
end
