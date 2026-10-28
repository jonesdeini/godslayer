# Drop the images table - derive photo URLs from raw instead

Written 2026-10-27, for a future session to pick up and execute - not started yet
(beyond already dropping the unused `image_processing` gem on this same branch).
Delete this file once it's actually built (fold the "why" into the implementing
commit's message instead, per this project's usual convention).

## Context

Worked through earlier this session: Rails most likely never downloads or stores
image bytes at all, for any future consumer, not just not-yet (see `CLAUDE.md`'s
Services section) - the actual consumer of image bytes is the future photo-sorter/
extraction phase (Python), which would fetch bytes directly from eBay's CDN at
processing time, with no Rails-side storage step ever needed.

That means the `images` table's only real reason to exist - tracking `local_path`/
`sha256`/`downloaded_at` for files Rails would download - no longer applies. And
once that's gone, a separate table is a third copy of data that already exists
twice: once in `listings.raw` (the full original eBay response, `image.imageUrl` +
`additionalImages[]`, never stripped), and once in whatever `ListingImporter`
derives from it to write `Image` rows. `images.source_url`/`position` add nothing
`raw` doesn't already have.

## Approach

**1. Migration** — drop the table entirely:
```ruby
def change
  drop_table :images
end
```

**2. Delete**, not deprecate:
- `app/models/image.rb`
- `app/services/image_writer.rb`
- `test/services/image_writer_test.rb`
- Any `test/models/image_test.rb` if one exists
- The `has_many :images, dependent: :destroy` line in `app/models/listing.rb`
- The stale clause in `CLAUDE.md`'s Services section (the Go bullet) that still
  says a future Go scraper would send `local_path`/`sha256` through the API as
  image metadata - both columns are gone after this, so that clause needs fixing
  (or dropping) as part of this same change, not as a separate pass
- The `write_images`/`image_urls` method and the `ImageWriter.write` call inside
  `app/services/listing_importer.rb`'s `import` - `ListingImporter` no longer
  writes anything image-related at all once there's no table to write to.

**3. Add two separate methods on `Listing`, not one merged ordered list** - this
was explicitly decided deliberately, not just the easy option: eBay's own data
already distinguishes a primary image (`raw["image"]`, singular) from additional
ones (`raw["additionalImages"]`, plural) - merging them into one array with an
implicit "index 0 is always primary" convention would be exactly the kind of
unstated contract this project has caught and fixed elsewhere. So:
```ruby
class Listing < ApplicationRecord
  def primary_image_url
    raw.dig "image", "imageUrl"
  end

  def additional_image_urls
    Array(raw["additionalImages"]).filter_map { |image| image["imageUrl"] }
  end
end
```
This is the same logic `ListingImporter#image_urls` already has, just split into
two explicit methods instead of one flattened list, and moved from a one-time
write-time computation to an on-read computation (no storage, no sync-keeping).

**4. Update tests:**
- `test/services/listing_importer_test.rb` - remove the image-related tests
  ("imports every image in order", "handles an item with only a primary image");
  `ListingImporter` has nothing left to test about images once it does nothing
  with them.
- New `test/models/listing_test.rb` tests for `primary_image_url`/
  `additional_image_urls` against `ListingImporterTest`'s existing
  `REAL_SHAPED_DETAIL` fixture shape (same real-sandbox-response shape already
  used there) - covering: both present, only primary present (no
  `additionalImages` key at all), and primary missing entirely (shouldn't
  happen in practice but shouldn't raise either).

## Verification

- `mise exec -- bin/rails test` — full suite green.
- `mise exec -- bin/rubocop` and `mise exec -- bin/brakeman -q` — clean.
- Confirm no other references to `Image`, `ImageWriter`, or `images` remain
  anywhere in `app/`/`test/` after the deletes (a plain `grep -rn` pass).
