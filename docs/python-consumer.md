# Python consumer — pipeline shape and design notes (discussed 2026-10-29, nothing built yet)

Dense working notes, kept separate from `CLAUDE.md` for the same reason as `ebay-api.md`: only relevant once actually building the Python consumer, not most other work in this repo. Nothing here is settled architecture - see `CLAUDE.md`'s Open section for what's actually decided vs. still open.

## The pipeline, as currently understood

1. Consume `{listing_id}` off `listing_ready`.
2. `GET /api/listings/:id` → metadata + image URLs.
3. Download the images.
4. Photo-sort — classify which photos are useful (BIOS/iLO screen, DIMM label vs. box art) — no value judgment yet, per `CLAUDE.md`'s funnel-stages note.
5. Extract — read the actual specs off the useful photos.
6. Write the determination back to Rails.

**The first vertical slice is just step 1** — a Python process that connects to RabbitMQ and consumes `{listing_id}` off `listing_ready`. Not the API call, not photo-sort, not extraction, not the write-back. Step 2 (calling the read API) is the next slice after that one's working and checked in.

## Why `description` needs adding to the read API before step 2

`GET /api/listings/:id` (`Api::ListingsController#listing_json`) doesn't expose `description` or `raw` at all today - only specific columns plus the derived `primary_image_url`/`additional_image_urls`. But the real, specific version of a spec claim (not just a vague structured aspect) usually only lives in the seller's free-text HTML description - confirmed directly against the real production API, and `Listing.from_ebay_json` already stores it verbatim as part of `raw`, so no scraper change is needed, just exposing what's already captured. This is prep work on the Rails side for the step-2 slice, not part of step 1, and not something step 1's Python work is blocked on.

## Concurrency - reasoning so far, not yet built against

- Downloading images (step 3) is I/O-bound - threads/async, not multiprocessing, regardless of what extraction ends up being.
- If extraction (step 5) calls a hosted vision-capable LLM per image, that's also I/O/rate-limit-bound - concurrent requests under a limiter, not raw process count. More processes just means hitting that rate limit faster.
- Multiprocessing/GPU batching only becomes the right lever if/when a self-hosted model exists to run locally - not relevant to the current slice.

## Extraction approach - a teacher/student idea, sequencing not confirmed

Idea: use a hosted vision-capable LLM to label images now, train a cheap self-hosted model later once there's a known accuracy ceiling and real labeled volume. Recommended sequencing (not yet confirmed as decided) mirrors the Ruby-before-Go reasoning in `CLAUDE.md`: validate with the hosted model first, capture every `(image, hosted-output)` pair as a free byproduct of doing so, and don't build the training/distillation loop speculatively before there's real signal to train on.

Where that captured `(image, label)` data would live (Python's own storage vs. something Rails-owned) is explicitly a future problem - not relevant to the current slice.

## Python tooling candidates - discussed, not committed

- `python-dotenv` - closest analog to `dotenv-rails`.
- `pika` - closest analog to `bunny`: same AMQP 0-9-1 protocol, blocking/sync by default unless there's a specific reason to reach for `aio-pika` instead.
