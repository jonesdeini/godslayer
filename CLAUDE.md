# godslayer — eBay homelab deal scanner

A living plan. Update this file as decisions actually get made in conversation — don't treat it as finished, and don't let it get stale.

## What this is

Scans eBay listings for underpriced/mislisted homelab gear (DDR4-era Xeon servers & workstations, ECC RDIMMs) by reading the *listing photos* (BIOS/iLO screens, DIMM labels) instead of trusting the title or price. Sellers often get specs wrong in both directions; the photos tell the truth.

## Why this project exists — read this first

This is Rob's project to learn and to be able to defend in an interview. The point is **not** a working app that Claude built — it's Rob understanding and owning every architecture decision. That changes how Claude should behave here:

- Rob makes the calls — architecture, naming, library choices, all of it. Claude's job is to lay out tradeoffs and ask, not to pick and implement.
- Work in small increments. Do one piece, stop, check in. Don't chain multiple files or services together without pausing for input.
- This file and any other planning doc are rough sketches of the idea, not specs. Nothing is "settled" just because it's written down — if it matters, re-derive it in conversation and record the real decision here.
- Default to the simplest thing that works for the current scale. Don't add CI path filters, codegen, abstractions, etc. until there's an actual pain point driving it.
- Default to Rails' own omakase convention (whatever `rails new` gives you with no extra gem) over a popular-but-bolted-on alternative. A deviation is fine, but it needs a stated reason at the time it's made, not just "that's what reef-1000 does" or "this gem is common."
- Prefer commit messages over code comments for explaining *why* something is the way it is. Keep inline comments terse (match Rails' own default comment density, not longer); put the reasoning, tradeoffs, and what was tried in the commit message instead. Every commit message should say why the change is being made, not just what changed.

## Decided so far

**Services, and why Rails is the whole app right now:**
- Rails app lives at the repo root (module `Godslayer`, `rails new .`). It is the *only* thing with database credentials, full stop — not just migrations/`schema.rb` (ActiveRecord migrations, not `structure.sql`), but all reads and writes, for every table.
- The scraper is **Ruby code inside this same Rails app** (a service object + a recurring Solid Queue job, not a separate process) — for now. Reasoning: a separate Go service sharing the same Postgres instance is a real anti-pattern (schema becomes an untyped cross-language contract, no enforcement beyond convention that a service only writes what it owns). Collapsing the scraper into Rails deletes that problem entirely for this boundary, and Ruby is perfectly adequate for a politely-rate-limited I/O-bound poller — there's no concurrency win from Go here worth the cross-language coupling.
- Go is **deferred, not cancelled**. If/when it comes back (for practice, or because of an actual limitation hit in Ruby), it comes back as a real separate service that talks to Rails **over an HTTP API that Rails exposes — it never touches Postgres directly.** That turns "don't write what you don't own" from a convention into something enforced by construction (Go simply has no DB credentials to misuse), and turns schema drift into a normal, well-tooled API-versioning problem instead of a cross-language ORM-drift problem. Images would still be written straight to the shared NAS path by Go (not base64'd through an API) — only lightweight metadata (`source_url`, `local_path`, `sha256`, `position`) would go through the API call.
- Explicit reasoning for the sequencing, not just "Ruby is easier": the Go-with-a-pushing-API architecture is the *better end state* — but validating the eBay integration and the data model is the risky, uncertain part right now, and the Ruby-in-Rails version gets that validated fastest with the least thrown away. Once the data model's proven out, swapping the producer (Ruby job → Go service hitting the same API) is a clean, well-scoped change that doesn't touch the consumer side at all. Ship the uncertain part cheaply first; the better architecture is still coming, deliberately, not abandoned.
- Python ML worker (`ml/`) — future, explicitly unresolved (see Open). Will cross into Rails' data somehow (API or direct read access) when it's actually built, not before.

**Why not a shared-database "ingester" model generally:** shared-database is a known anti-pattern (implicit untyped contracts, no encapsulation, partial-write visibility to other readers) — it's being avoided outright for Go by keeping Rails as the sole DB owner, rather than mitigated with DB-level grants/roles. That mitigation (per-service Postgres roles) is still a reasonable fallback to remember if a second service ever does need direct DB access, but it's not the current plan.

**CI:** run the full test suite on every change, no path-based filtering — premature optimization for this scale, and it would undermine the one thing that would actually catch a Rails-vs-everyone-else contract break.

**Repo layout:** the Rails app occupies the repo root. `ml/` is a placeholder for the future Python service. No `ingester/` directory exists right now — it gets created later, as a sibling, only if/when Go actually comes back as a real API client.

**Secrets:** plain `SECRET_KEY_BASE` env var, not Rails' default `config/credentials.yml.enc` + `master.key`. A deliberate, stated deviation from omakase (see the collaboration rule above) — nothing else was ever stored in credentials.yml.enc, and running two parallel secret mechanisms for one value wasn't worth it. The actual reason it tipped this way: plaintext `.env.example`/`.env.test` diffs are reviewable in git history, an encrypted credentials blob's aren't.

**Deploy:** same shape as reef-1000 — `docker-compose.yml` (postgres + web + jobs + a poll-based `updater`) and a `build_and_push` CI job to GHCR, gated on `lint`/`test`/`scan_ruby` passing. This is going on the same home Unraid box as reef-1000 (Urithiru), so the same reasoning applies: Kamal-over-SSH would need a path into the LAN for a GitHub-hosted runner to reach, which the `updater` avoids entirely (the box only ever reaches out to `docker pull`, GitHub never executes anything on it). Kamal, Solid Cache, and Solid Cable were all stripped from the Rails 8 defaults — Kamal because it's not the deploy mechanism, Cache/Cable because nothing uses a cache store or ActionCable yet and keeping them would mean provisioning 2 more logical Postgres databases for nothing. Production now has just `primary` + `queue` (Solid Queue, for the recurring scrape job).

**Search strategy:**
- Category sweeps (no keyword) and keyword sweeps (no category) are run as separate, independent searches — never combined into one API call. Reasoning: category sweeps catch listings a keyword search structurally can't (a seller who doesn't know what model they have can't type it in the title, but the listing still lands in *some* category); keyword sweeps catch listings a category sweep can't (a seller who typed the right model but miscategorized the listing). Combining them into one call would cost real recall (missing correctly-labeled-but-miscategorized listings) for a precision benefit that's small given how specific the actual keywords are (model numbers, misspellings, RAM part numbers rarely collide across categories anyway).
- Price cap is a single global env var (e.g. `PRICE_CAP_CENTS`), not per-search-term — it's a scalar affordability threshold ("can we afford to even look at this"), not a growing collection, so it follows the config-not-DB-settings reasoning below rather than the search-terms-as-data reasoning.
- Search terms (which categories, which keywords) are modeled as **two separate DB tables/resources** (`search_categories`, `search_keywords`), not env vars and not one `search_terms` table with a `kind` column. Reasoning: these are a growing, edited-over-time collection (not a single-tenant config scalar — see reef-1000's "config, not database-backed settings" principle, which this *doesn't* contradict since that rule was about identity/credential scalars, not collections with their own lifecycle), and a category has genuinely different attributes than a keyword (an external taxonomy ID + optional human-readable name, vs. just a free-text phrase) — forcing both into one `kind`/`value` table loses that and relies on app logic instead of the schema to keep them mutually exclusive. Not yet migrated.

**Funnel stages, clarified:** scraper (now) is purely an affordability filter — "get everything that fits our search criteria and the price cap." The photo sorter (plan's phase 2) classifies which photos are even useful, no value judgment yet. Extraction (phase 3) reads the true specs off those photos. A **deal scorer** (the plan's own "Later" phase) is a distinct fourth stage — diffing extracted true specs against current market prices for those specific components to actually rank deals. That only works if extraction produces structured fields (e.g. "4x 32GB DDR4 RDIMM"), not prose — worth keeping in mind for how extraction gets designed later, nothing to act on now.

## Open / not yet decided

- The plan's original "Datasette for zero-code DB browsing" doesn't work — Datasette is SQLite-only, no Postgres plugin exists on PyPI. Need to actually decide between pgweb, Adminer, or a db-to-sqlite sync + real Datasette. Explicitly deferred — not worth deciding before there's real data to browse.
- eBay category IDs for the search sweeps — need to actually look these up via the Taxonomy API, not guess.
- The scraper itself hasn't been written yet — only the HTTP client + token caching (`Ebay::Base`/`Ebay::Authenticator`) exist so far, not search/item-detail calls, an importer, or the recurring job.
- `search_categories`/`search_keywords` migrations — shape decided (see above), not yet written.
- How Python/ML eventually gets at Rails' data — explicitly punted, not a today problem.
- The review UI itself — not discussed yet.
- The actual Unraid share path in `docker-compose.yml`'s `updater` service (`/mnt/user/godslayerrr/godslayer`) is still a guess, not confirmed against a real checkout on Urithiru.
- The old `master` branch still exists on GitHub (renamed to `main` locally and as the default branch, but deleting the remote `master` got blocked by the permission system as a destructive action) — needs explicit go-ahead to actually delete.

## State of the repo right now

- Rails app at the repo root (module `Godslayer`), `listings`/`images` migrations and models matching the schema below — migrated and verified against the test database and in a real `docker-compose` smoke test (production image boots, `/up` returns 200, both logical databases get created), but no persistent local development database exists yet.
- `app/services/ebay/base.rb` + `app/services/ebay/authenticator.rb` — the only scraper code written so far (HTTP client + OAuth2 token caching, TDD'd with Minitest + WebMock, reef-1000-style conventions: namespaced, no-parens-on-calls, `self.verb = new.verb` delegation). No search, item-detail, importer, or job code yet.
- Kamal, Solid Cache, and Solid Cable removed; Rails credentials/master key removed in favor of a plain `SECRET_KEY_BASE` env var (see "Secrets" above).
- `docker-compose.yml`, `Dockerfile`, `docker/postgres/init-queue-db.sh` exist and are verified working end-to-end locally — not yet deployed to Urithiru.
- CI (`.github/workflows/ci.yml`): `lint`, `test`, `scan_ruby`, `build_and_push` all green on every push to `main`; `build_and_push` pushes to GHCR.
- `ml/` — empty placeholder.
- Root: `.env`/`.env.example` current and accurate (`SECRET_KEY_BASE`, eBay creds), `.gitignore`/`.dockerignore` cleaned up, `mise.toml` (pins ruby/go/python — go pin harmless to keep for whenever it's needed again).

## Schema

**Migrated (`db/migrate/`):**

```ruby
create_table :listings do |t|
  t.string   :ebay_item_id, null: false   # unique index — dedupe/upsert key
  t.string   :title, null: false
  t.integer  :price_cents, null: false
  t.string   :currency, null: false, default: "USD"
  t.string   :condition
  t.string   :category_id
  t.string   :seller
  t.string   :item_location
  t.string   :url, null: false
  t.jsonb    :raw, null: false            # full eBay item-detail response — never lose a field
  t.datetime :first_seen_at, null: false
  t.datetime :last_seen_at, null: false
  t.timestamps
end

create_table :images do |t|
  t.references :listing, null: false, foreign_key: { on_delete: :cascade }
  t.integer  :position, null: false
  t.string   :source_url, null: false
  t.string   :local_path                 # null until downloaded
  t.string   :sha256                     # dedupe identical photos across listings
  t.datetime :downloaded_at
  t.timestamps
  # unique index on [:listing_id, :position]
end
```

**Planned, not yet migrated:**

```ruby
create_table :search_categories do |t|
  t.string  :ebay_category_id, null: false
  t.string  :name                        # human-readable, for your own reference
  t.boolean :active, null: false, default: true
  t.timestamps
end

create_table :search_keywords do |t|
  t.string  :phrase, null: false
  t.boolean :active, null: false, default: true
  t.timestamps
end
```
