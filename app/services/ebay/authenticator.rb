module Ebay
  class Authenticator
    TOKEN_URL = "https://api.ebay.com/identity/v1/oauth2/token".freeze
    SCOPE = "https://api.ebay.com/oauth/api_scope".freeze

    def self.token
      @token = nil if @expires_at && Time.now >= @expires_at
      @token ||= fetch_token
    end

    # Clears the cached token. The token is memoized at the class level (it
    # must survive across many calls, unlike Apex's per-instance cookie
    # re-auth), so tests need an explicit way to reset it between examples.
    def self.reset!
      @token = nil
      @expires_at = nil
    end

    def self.fetch_token
      response = HTTP.basic_auth(
        user: Rails.application.config.x.ebay.client_id,
        pass: Rails.application.config.x.ebay.client_secret
      ).post(TOKEN_URL, form: { grant_type: "client_credentials", scope: SCOPE })

      body = JSON.parse(response.body.to_s)
      @expires_at = Time.now + body.fetch("expires_in").to_i
      body.fetch("access_token")
    end
    private_class_method :fetch_token
  end
end
