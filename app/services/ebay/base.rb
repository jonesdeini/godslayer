# frozen_string_literal: true

module Ebay
  class Base
    API_HOSTS = { "sandbox" => "api.sandbox.ebay.com", "production" => "api.ebay.com" }.freeze

    def self.api_host
      API_HOSTS.fetch Rails.application.config.x.ebay.environment
    end

    private

    def get(path)
      HTTP.timeout(30)
          .auth("Bearer #{Ebay::Authenticator.token}")
          .headers("X-EBAY-C-MARKETPLACE-ID" => Rails.application.config.x.ebay.marketplace_id)
          .get(path)
          .body
          .to_s
    end

    def base_url
      "https://#{self.class.api_host}/buy/browse/v1"
    end
  end
end
