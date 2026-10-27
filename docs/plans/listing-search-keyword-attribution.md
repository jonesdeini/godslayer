# Track which SearchKeyword(s) found each Listing

Written 2026-10-27, for a future session to pick up and execute - not started yet.
Delete this file once it's actually built (fold the "why" into the implementing
commit's message instead, per this project's usual convention).

## Context

Right now a `Listing` has no link back to the `SearchKeyword`(s) that surfaced it. Traced the actual call path: `SweepSchedulerJob#perform` enqueues `KeywordSweepJob.perform_later keyword.phrase` — just the bare phrase string. `KeywordSweepJob#perform(phrase)` uses it only for the `Ebay::Search.keyword(phrase)` call, then drops it. `ListingImporter.import(raw_json)` takes only the raw eBay JSON, with zero awareness of which keyword produced it. Nobody decided this on purpose; it fell out of building the pipeline incrementally (prove search → prove import → add keywords later) before attribution ever came up.

Fixing it because there's real value on both ends: UI value (show which keyword(s) found a given listing) and evaluation value (tell which keywords are actually worth keeping, by seeing what they've produced).

## Why this is a join table, not a simple FK column

The relationship is genuinely many-to-many: the same listing can be surfaced by more than one keyword sweep (e.g. two overlapping phrasings both matching it), and `ListingWriter` already upserts by `ebay_item_id` as a single identity row per listing. A plain `search_keyword_id` column on `listings` would silently overwrite with "whichever keyword swept it last," losing every other keyword that also found it. A join table is the only way to record all of them.

## Approach

**1. Migration** — new join table `listing_search_keywords`:
```ruby
create_table :listing_search_keywords do |t|
  t.belongs_to :listing, null: false, foreign_key: true
  t.belongs_to :search_keyword, null: false, foreign_key: true
  t.timestamps
end
add_index :listing_search_keywords, [:listing_id, :search_keyword_id], unique: true
```
`created_at` = first time this keyword surfaced this listing. `updated_at` will bump on every later sweep that reconfirms the same pairing (since the write is an idempotent upsert, same mechanism already used for `last_seen_at` on `listings`) — gives "last confirmed by this keyword" for free with no extra column.

**2. Model** — `app/models/listing_search_keyword.rb`:
```ruby
class ListingSearchKeyword < ApplicationRecord
  belongs_to :listing
  belongs_to :search_keyword
end
```
Add to `app/models/listing.rb`: `has_many :listing_search_keywords` + `has_many :search_keywords, through: :listing_search_keywords`.
Add to `app/models/search_keyword.rb`: `has_many :listing_search_keywords` + `has_many :listings, through: :listing_search_keywords`.

**3. Writer service** — `app/services/listing_search_keyword_writer.rb`, matching the existing `ImageWriter`/`ListingWriter` upsert convention exactly (`app/services/image_writer.rb` is the closest template — same two-FK-column shape):
```ruby
class ListingSearchKeywordWriter
  def self.write(listing_id:, search_keyword_id:)
    ListingSearchKeyword.upsert(
      { listing_id:, search_keyword_id: },
      unique_by: [ :listing_id, :search_keyword_id ]
    )
  end
end
```

**4. Thread the keyword through the pipeline:**
- `app/jobs/sweep_scheduler_job.rb`: change `KeywordSweepJob.perform_later keyword.phrase` to `KeywordSweepJob.perform_later keyword` — ActiveJob serializes an ActiveRecord object via GlobalID automatically, so this is a safe, idiomatic change, not a new mechanism.
- `app/jobs/keyword_sweep_job.rb`: `perform(keyword)` instead of `perform(phrase)`. Use `keyword.phrase` for the `Ebay::Search.keyword(...)` call. Pass `keyword.id` into `import_item`, which passes `search_keyword_id:` into `ListingImporter.import`.
- `app/services/listing_importer.rb`: `self.import(raw_json, search_keyword_id:)` / `import(raw_json, search_keyword_id:)` — new required kwarg. After `write_listing` returns `listing_id`, call `ListingSearchKeywordWriter.write(listing_id:, search_keyword_id:)` before `write_images`.

**5. Update existing tests to match the new signatures** (no behavior to stub beyond what's already stubbed):
- `test/jobs/sweep_scheduler_job_test.rb`: `assert_enqueued_with` should expect `args: [ search_keywords(:one) ]` (the record), not `.phrase`.
- `test/jobs/keyword_sweep_job_test.rb`: call `KeywordSweepJob.perform_now search_keywords(:one)` instead of a bare string in every test; add one new assertion confirming a `ListingSearchKeyword` row now links the imported listing to that fixture keyword.
- `test/services/listing_importer_test.rb`: every `ListingImporter.import(...)` call needs `search_keyword_id: search_keywords(:one).id` added; add an assertion that the join row exists after import.

**6. New tests:**
- `test/models/listing_search_keyword_test.rb` — uniqueness of the `[listing_id, search_keyword_id]` pairing, matching how `search_keyword_test.rb` already tests `SearchKeyword`'s own uniqueness validation.
- `test/services/listing_search_keyword_writer_test.rb` — matching `test/services/image_writer_test.rb`'s shape: creates on first write, idempotent (no duplicate row) on a second write with the same ids.

## Explicitly out of scope for this change

No UI surface for this yet (e.g. showing matched keywords on a listing, or listing counts on the `search_keywords` show page) — that's a separate future slice once there's an actual listings-review UI to put it in. This change is just making the data exist and be correct.

## Verification

- `mise exec -- bin/rails test` — full suite green, including the updated and new tests above.
- `mise exec -- bin/rubocop` and `mise exec -- bin/brakeman -q` — clean, same as every other slice this session.
- Manual sanity check via `bin/rails runner` against the dev DB: run `KeywordSweepJob.perform_now(SearchKeyword.first)` against a stubbed/sandbox response (or reuse the existing real-sandbox verification pattern already established in this project) and confirm `ListingSearchKeyword.count` increases and correctly references both the listing and the keyword.
