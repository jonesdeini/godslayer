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

## Open / not yet decided

- The plan's original "Datasette for zero-code DB browsing" doesn't work — Datasette is SQLite-only, no Postgres plugin exists on PyPI. Need to actually decide between pgweb, Adminer, or a db-to-sqlite sync + real Datasette.
- Whether to keep the Rails 8 defaults that `rails new` pulled in (Kamal deploy config, Solid Queue/Cache/Cable, importmap/Turbo/Stimulus) or strip what doesn't end up used.
- eBay category IDs for the search sweeps — need to actually look these up via the Taxonomy API, not guess.
- The scraper itself hasn't been written yet (service object + recurring job — not started).
- How Python/ML eventually gets at Rails' data — explicitly punted, not a today problem.
- `docker-compose.yml` — not written yet; now simpler without a separate ingester container.
- The review UI itself — not discussed yet.

## State of the repo right now

- Rails app at the repo root (`bin/rails`, `app/`, `config/`, etc. — module `Godslayer`), plus hand-written `listings`/`images` migrations and models matching the schema below. **Migrations have never been run** — no database exists yet, and the scraper service object/job hasn't been written.
- `ml/` — empty placeholder.
- Root: `.env` / `.env.example` (stale — still reference the old Go ingester's env vars and the old `deal_scanner_development` DB name; need a pass), `.gitignore`, `mise.toml` (pins ruby/go/python via `mise` — go pin is harmless to keep around for whenever it's needed again).
- Nothing has been committed to git yet.

## Schema (as currently migrated by hand in `db/migrate/`)

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
