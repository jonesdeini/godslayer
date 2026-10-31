# godslayer-ml

The Python consumer side of godslayer. Consumes `{listing_id}` messages off RabbitMQ's `listing_ready` queue, published by the Rails app once a listing's images are downloaded, fetches the listing's data (including image URLs) from the Rails read API, downloads each image, and runs it through Tesseract OCR. See the root `CLAUDE.md` and `docs/python-consumer.md` for the full design context - no comparison/determination logic yet, this just logs what OCR finds.

## Setup

Needs the real Tesseract binary installed separately (`pytesseract` is just a wrapper around it) - e.g. `apt install tesseract-ocr` / `brew install tesseract`.

```
cp .env.example .env
uv sync
```

## Run

```
uv run godslayer-ml
```

## Test

No broker needed - `handle_message` is tested with a mocked channel, same reasoning as the Rails side's switch to `bunny-mock` (no per-test isolation for an external queue, and little broker-specific behavior worth a live dependency for this thin a wrapper).

```
uv run pytest
```
