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
uv run --group training pytest
```

## Train and upload the title classifier

Deploy the Rails model-upload endpoint from PR #46 first. The target Rails app
must expose `GET /api/listing_labels` and `POST /api/title_classifier_models`,
and have labeled examples of both computers and parts.

From `ml/`, configure `GODSLAYER_API_URL` in `.env` for the intended Rails app,
then run:

```
uv run --group training python -m training.train_classifier
```

This fetches the labels, trains a TF-IDF/logistic regression pipeline, prints
its holdout evaluation, and uploads JSON vocabulary and weights as a new active
model version. Uploading replaces the active model used by Rails sweeps.
It does not write a local joblib artifact. Training dependencies are installed
only with the `training` group and are excluded from the production consumer image.
