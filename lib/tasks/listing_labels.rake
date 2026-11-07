# frozen_string_literal: true

namespace :listings do
  desc "Label existing listings computer/part via a frontier LLM - costs real money, see secret_sauce"
  task label: :environment do
    limit = ENV.fetch("LIMIT", "50").to_i
    force = ActiveModel::Type::Boolean.new.cast ENV["FORCE"]
    ListingLabeler.label_all limit:, force:
  end
end
