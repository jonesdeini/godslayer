# frozen_string_literal: true

class SearchKeywordSeeder
  DEFAULT_PATH = Rails.root.join "search_terms.json"

  def self.seed(path: DEFAULT_PATH)
    new(path).seed
  end

  def initialize(path)
    @path = path
  end

  def seed
    raise "#{@path} not found - it's gitignored, create it locally before seeding." unless File.exist? @path

    entries = JSON.parse File.read(@path)

    entries.each do |entry|
      SearchKeyword.upsert(
        {
          phrase: entry.fetch("phrase"),
          exclude_phrase: entry["exclude_phrase"],
          active: entry.fetch("active", true)
        },
        unique_by: :phrase,
        update_only: [ :exclude_phrase, :active ]
      )
    end

    seeded_phrases = entries.map { |entry| entry.fetch "phrase" }
    SearchKeyword.where(active: true).where.not(phrase: seeded_phrases).update_all active: false
  end
end
