# Python consumer — pipeline shape and design notes (discussed 2026-10-29/30/31)

Dense working notes, kept separate from `CLAUDE.md` for the same reason as `ebay-api.md`: only relevant once actually building the Python consumer, not most other work in this repo. Nothing here is settled architecture - see `CLAUDE.md`'s Open section for what's actually decided vs. still open.

## The pipeline, as currently understood

1. Consume `{listing_id}` off `listing_ready`. **Built.**
2. `GET /api/listings/:id` → metadata + image URLs. **Built.**
3. Download the images. **Built.**
4. Photo-sort — classify which photos are useful (BIOS/iLO screen, DIMM label vs. box art) — no value judgment yet, per `CLAUDE.md`'s funnel-stages note. **Collapsed into extraction for the current MVP** - see `secret_sauce/mvp-strategy.md` (gitignored) for why a separate classification pass isn't built.
5. Extract — read the actual specs off the useful photos. **OCR pass built** (`pytesseract`, the real Tesseract binary) on every downloaded image, logged. **Comparison/determination logic validated but not yet built into the pipeline** - see `secret_sauce/mvp-strategy.md` for the approach (a local LLM distills structured claims from the listing text and separately from the OCR text into a shared schema, then plain code does the actual comparison) and why an end-to-end "one model call does extraction and comparison together" approach didn't work reliably.
6. Write the determination back to Rails. **Not built** - still genuinely open, see `CLAUDE.md`.

Verified end-to-end against real services (2026-10-31): a real RabbitMQ message → real `GET /api/listings/:id` call → a real downloaded image → real Tesseract OCR output. Found and fixed a real bug this way - the API was handing out relative, not absolute, blob URLs (see git history / PR for `app/views/api/listings/show.json.jbuilder`).

## Comparison step - general shape (specifics in `secret_sauce/mvp-strategy.md`)

The determination step splits across two tools, each used for what it's actually reliable at: a local LLM (via Ollama) handles fuzzy text extraction/normalization (robust to OCR noise and varied listing phrasing), and plain deterministic code handles unit conversion and threshold comparison (no LLM arithmetic). Local-only, not a hosted API - a real cost constraint for this project, not a style choice. Model/schema/hardware specifics are in the gitignored strategy doc.

## Concurrency - reasoning so far, not yet built against

- Downloading images (step 3) is I/O-bound - threads/async, not multiprocessing, regardless of what extraction ends up being.
- OCR itself (step 5, Tesseract) is CPU-bound, not I/O-bound - multiprocessing/batching is the right lever here if throughput ever becomes a real problem, not async. Not built - current pass processes one image at a time, synchronously, inside message handling.
- If extraction ever calls a hosted vision-capable LLM per image (see `secret_sauce/mvp-strategy.md`'s fallback-path note), that's I/O/rate-limit-bound instead - concurrent requests under a limiter, not raw process count.

## Python tooling, in use

- `python-dotenv` - `.env` loading.
- `pika` - RabbitMQ client, blocking/sync.
- `requests` - the HTTP client for both the Rails read API and downloading images.
- `pytesseract` - thin wrapper around the real Tesseract OCR binary (must be installed on the host separately - not a pure-Python dependency).
