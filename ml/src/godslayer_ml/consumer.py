import json
import logging
import time
from functools import partial

import pika
import requests

from godslayer_ml.pipeline import process_listing

QUEUE_NAME = "listing_ready"
DEAD_QUEUE_NAME = "listing_ready.dead"

MAX_ATTEMPTS = 3
RETRY_DELAY_SECONDS = 5

logger = logging.getLogger(__name__)


def connect(amqp_url: str) -> pika.BlockingConnection:
    return pika.BlockingConnection(pika.URLParameters(amqp_url))


def is_permanent_failure(exc: Exception) -> bool:
    if isinstance(exc, requests.exceptions.HTTPError) and exc.response is not None:
        return 400 <= exc.response.status_code < 500
    return False


def handle_message(channel, method, properties, body, api_base_url: str, ollama_url: str) -> int:
    listing_id = json.loads(body)["listing_id"]
    logger.info("received listing_ready for listing_id=%s", listing_id)

    attempt = 1
    while True:
        try:
            process_listing(listing_id, api_base_url, ollama_url)
            channel.basic_ack(delivery_tag=method.delivery_tag)
            return listing_id
        except Exception as exc:
            out_of_attempts = attempt >= MAX_ATTEMPTS
            if is_permanent_failure(exc) or out_of_attempts:
                logger.exception(
                    "failed to process listing_id=%s on attempt %s/%s, sending to %s",
                    listing_id,
                    attempt,
                    MAX_ATTEMPTS,
                    DEAD_QUEUE_NAME,
                )
                channel.basic_publish(exchange="", routing_key=DEAD_QUEUE_NAME, body=body)
                channel.basic_ack(delivery_tag=method.delivery_tag)
                return listing_id

            logger.warning(
                "attempt %s/%s failed for listing_id=%s (%s), retrying in %ss",
                attempt,
                MAX_ATTEMPTS,
                listing_id,
                exc,
                RETRY_DELAY_SECONDS,
            )
            time.sleep(RETRY_DELAY_SECONDS)
            attempt += 1


def run(amqp_url: str, api_base_url: str, ollama_url: str) -> None:
    connection = connect(amqp_url)
    channel = connection.channel()
    channel.queue_declare(queue=QUEUE_NAME, durable=True)
    channel.queue_declare(queue=DEAD_QUEUE_NAME, durable=True)
    on_message = partial(handle_message, api_base_url=api_base_url, ollama_url=ollama_url)
    channel.basic_consume(queue=QUEUE_NAME, on_message_callback=on_message)

    try:
        channel.start_consuming()
    finally:
        connection.close()
