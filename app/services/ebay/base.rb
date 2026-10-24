# frozen_string_literal: true

module Ebay
  class Base
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
      "https://api.ebay.com/buy/browse/v1"
    end
  end
end
