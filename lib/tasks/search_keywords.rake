# frozen_string_literal: true

namespace :search_keywords do
  desc "Seed search_keywords from search_terms.json (gitignored, not in the repo)"
  task seed: :environment do
    SearchKeywordSeeder.seed
  end
end
