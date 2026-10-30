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

Needs a real RabbitMQ broker reachable at `RABBITMQ_URL` (defaults to `amqp://guest:guest@localhost:5672`) - tests run against it for real, not mocked, same as the Rails side.

```
uv run pytest
```
