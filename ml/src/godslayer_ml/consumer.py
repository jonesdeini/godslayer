import json
import logging
from functools import partial

import pika

from godslayer_ml.pipeline import process_listing

QUEUE_NAME = "listing_ready"

logger = logging.getLogger(__name__)


def connect(amqp_url: str) -> pika.BlockingConnection:
    return pika.BlockingConnection(pika.URLParameters(amqp_url))


def handle_message(channel, method, properties, body, api_base_url: str) -> int:
    listing_id = json.loads(body)["listing_id"]
    logger.info("received listing_ready for listing_id=%s", listing_id)
    process_listing(listing_id, api_base_url)
    channel.basic_ack(delivery_tag=method.delivery_tag)
    return listing_id


def run(amqp_url: str, api_base_url: str) -> None:
    connection = connect(amqp_url)
    channel = connection.channel()
    channel.queue_declare(queue=QUEUE_NAME, durable=True)
    on_message = partial(handle_message, api_base_url=api_base_url)
    channel.basic_consume(queue=QUEUE_NAME, on_message_callback=on_message)

    try:
        channel.start_consuming()
    finally:
        connection.close()
