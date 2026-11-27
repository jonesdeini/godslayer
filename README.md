# godslayer

Finds underpriced homelab gear on eBay (DDR4-era Xeon servers and workstations) by reading the **listing photos** instead of trusting the title or price.

Sellers get specs wrong in both directions. A listing titled "16GB" might have a BIOS screenshot showing 256GB installed, or the reverse. The photos (BIOS/iLO screens, DIMM labels) are usually more accurate than the text, so godslayer OCRs them, extracts what they actually show, and flags listings where the photos and the claim disagree.

## The name

People used to call it *sniping* when you grabbed an eBay auction in its last seconds. A sniping tool needed a rifle, but most fantasy series don't have guns. Sarah J. Maas's *Crescent City* does, and the Godslayer rifle in it has a great name.

## How it works

```
eBay Browse API
      │  keyword sweeps (Solid Queue)
      ▼
┌─────────────────────────── Rails ───────────────────────────┐
│ search summary → ListingCandidate → TitleClassifier         │
│                     "part" ─▶ stop (no detail call)         │
│                     "computer" ─▶ detail call → Listing     │
│ download every photo (Active Storage) → publish listing_id  │
└──────────────────────────────┬──────────────────────────────┘
                               │ RabbitMQ: listing_ready
                               ▼
┌────────────────────────── ml (Python) ──────────────────────┐
│ GET /api/listings/:id → Tesseract OCR on each photo          │
│ local LLM (Ollama) extracts claimed + photographed RAM       │
│ plain code converts units and compares                       │
└──────────────────────────────┬──────────────────────────────┘
                               │ POST /api/listings/:id/determinations
                               ▼
                 Rails review UI: match / mismatch / no_evidence
```

- **Rails** owns the database outright. Nothing else gets Postgres credentials; the Python side only talks to Rails over HTTP.
- **The title classifier** (TF-IDF + logistic regression) is trained in Python on labeled listings, then runs inside Rails as plain Ruby arithmetic. Its job is to filter out loose parts before they cost an eBay detail call.
- **RabbitMQ** hands out the photo-analysis work, with ack/retry/dead-letter handling.
- **All models run locally** (Ollama). The one exception is an optional one-off labeling task for training data.

The reasoning behind each decision, including the ones that were reversed, is recorded in [`CLAUDE.md`](CLAUDE.md) and [`docs/`](docs/).

## Running locally

Needs Ruby, Python and [uv](https://docs.astral.sh/uv/) (versions are pinned in `mise.toml`), PostgreSQL, and for the `ml` side, RabbitMQ, [Ollama](https://ollama.com) and the `tesseract` binary.

```sh
cp .env.example .env     # fill in eBay credentials, see below
bin/setup                # installs gems, prepares the database, starts the server
bin/jobs                 # Solid Queue worker, in a second terminal
```

The UI is at <http://localhost:3000>. Keyword sweeps only run on a schedule in production (`SWEEP_INTERVAL_HOURS`). Locally, add a keyword in the UI and run `KeywordSweepJob.perform_now(SearchKeyword.first)` from `bin/rails console`.

The Python consumer has its own README: [`ml/README.md`](ml/README.md).

### eBay credentials

You need your own [eBay Developer Program](https://developer.ebay.com) keyset (App ID and Cert ID; the Dev ID isn't used). Set `EBAY_ENVIRONMENT` to `sandbox` or `production` to match. Sandbox returns synthetic listings only. Production keys fail with `401 invalid_client` until you file the **Marketplace Account Deletion** attestation in the developer portal. See [`docs/ebay-api.md`](docs/ebay-api.md).

## Tests

```sh
bin/rails test                         # Rails (needs Postgres; RabbitMQ is mocked)
bin/rubocop && bin/brakeman

cd ml
uv run --group training pytest         # Python (needs tesseract)
uv run ruff check . && uv run bandit -r src/ training/
```

CI runs all of the above on every push.

## Self-hosting

`docker-compose.yml` runs the whole system: Postgres, RabbitMQ, Ollama, `web`, `jobs` and `ml`, using the public images from `ghcr.io/jonesdeini/`. **It's written for the author's own home server**, so change these before using it:

- **`updater` / `updater_watchdog`**: a poll-based auto-deploy that hardcodes a path on that server. Remove both, or point them at your checkout.
- **`ollama`'s GPU reservation** assumes an NVIDIA GPU and the NVIDIA container runtime. Remove the `deploy:` block to run on CPU (much slower).
- **`TAILSCALE_IP`** controls which interface RabbitMQ's management UI binds to. If it's unset, the UI binds to `127.0.0.1`.

## Known limitations

- **A fresh install can't bootstrap the title classifier.** Sweeps need a trained model before they can promote anything into a `Listing`. Training needs labeled listings, and labels need existing listings. The current model was trained on listings collected before the classifier existed, so there's no first-run path yet.
- **No search keywords ship with the repo.** `rails search_keywords:seed` reads a private file. Add your own keywords through the UI.
- **The sweep schedule is off by default.** Unbounded pagination combined with eBay's unreliable rate-limit signaling can exhaust the daily API quota without any error showing up. See [`docs/keyword-sweep-quota-findings.md`](docs/keyword-sweep-quota-findings.md).
- **Only RAM is checked so far.** CPU and storage aren't extracted yet.
- **The HTTP API has no authentication.** It's intended for a trusted LAN only.
