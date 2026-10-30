# godslayer-ml

The Python consumer side of godslayer. Consumes `{listing_id}` messages off RabbitMQ's `listing_ready` queue, published by the Rails app whenever a genuinely new listing gets imported. See the root `CLAUDE.md` and `docs/python-consumer.md` for the full design context - this is step 1 of that pipeline only: connect and consume, nothing else yet.

## Setup

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
