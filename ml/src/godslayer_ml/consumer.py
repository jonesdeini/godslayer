import json
import logging
import signal
import time
from functools import partial

import pika
import requests
import tenacity

from godslayer_ml.pipeline import process_listing

QUEUE_NAME = "listing_ready"
DEAD_QUEUE_NAME = "listing_ready.dead"

MAX_ATTEMPTS = 3
RETRY_DELAY_SECONDS = 5

# Process one message at a time instead of RabbitMQ's unbounded-prefetch
# default - without this, a broker restart hands the consumer its entire
# ready backlog the instant it reconnects, so "messages ready" looks like
# it dropped to zero (really: everything just became unacked at once).
PREFETCH_COUNT = 1

# Same short-fixed-delay philosophy as RETRY_DELAY_SECONDS, kept as a
# separate constant since it's a different concern (broker reconnect, not
# per-listing processing retry) even though the value happens to match.
RECONNECT_DELAY_SECONDS = 5

logger = logging.getLogger(__name__)


def connect(amqp_url: str) -> pika.BlockingConnection:
    return pika.BlockingConnection(pika.URLParameters(amqp_url))


def is_permanent_failure(exc: Exception) -> bool:
    if isinstance(exc, requests.exceptions.HTTPError) and exc.response is not None:
        return 400 <= exc.response.status_code < 500
    return False


@tenacity.retry(
    stop=tenacity.stop_after_attempt(MAX_ATTEMPTS),
    wait=tenacity.wait_fixed(RETRY_DELAY_SECONDS),
    retry=tenacity.retry_if_exception(lambda exc: not is_permanent_failure(exc)),
    before_sleep=tenacity.before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
def process_listing_with_retry(listing_id: int, api_base_url: str, ollama_url: str) -> None:
    process_listing(listing_id, api_base_url, ollama_url)


def handle_message(channel, method, properties, body, api_base_url: str, ollama_url: str) -> int:
    listing_id = json.loads(body)["listing_id"]
    logger.info("received listing_ready for listing_id=%s", listing_id)

    try:
        process_listing_with_retry(listing_id, api_base_url, ollama_url)
    except Exception:
        logger.exception("failed to process listing_id=%s, sending to %s", listing_id, DEAD_QUEUE_NAME)
        channel.basic_publish(exchange="", routing_key=DEAD_QUEUE_NAME, body=body)

    channel.basic_ack(delivery_tag=method.delivery_tag)
    return listing_id


def run(amqp_url: str, api_base_url: str, ollama_url: str) -> None:
    stopping = False
    active_channel = None

    def handler(signum, frame):
        nonlocal stopping
        logger.info("received signal %s, finishing the in-flight message then stopping", signum)
        stopping = True
        if active_channel is not None:
            active_channel.stop_consuming()

    signal.signal(signal.SIGTERM, handler)
    signal.signal(signal.SIGINT, handler)

    while True:
        connection = connect(amqp_url)
        try:
            channel = connection.channel()
            channel.basic_qos(prefetch_count=PREFETCH_COUNT)
            channel.queue_declare(queue=QUEUE_NAME, durable=True)
            channel.queue_declare(queue=DEAD_QUEUE_NAME, durable=True)
            on_message = partial(handle_message, api_base_url=api_base_url, ollama_url=ollama_url)
            channel.basic_consume(queue=QUEUE_NAME, on_message_callback=on_message)
            active_channel = channel

            channel.start_consuming()
            return
        except pika.exceptions.AMQPConnectionError:
            logger.warning("lost connection to RabbitMQ, reconnecting in %ss", RECONNECT_DELAY_SECONDS, exc_info=True)
        finally:
            active_channel = None
            try:
                connection.close()
            except pika.exceptions.AMQPError:
                logger.debug("connection already closed while cleaning up")

        if stopping:
            return
        time.sleep(RECONNECT_DELAY_SECONDS)
