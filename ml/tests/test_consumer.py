import json
from unittest.mock import Mock, patch

import requests

from godslayer_ml.consumer import DEAD_QUEUE_NAME, MAX_ATTEMPTS, handle_message, is_permanent_failure


def test_handle_message_parses_the_listing_id_processes_it_and_acks():
    channel = Mock()
    method = Mock(delivery_tag=1)
    body = json.dumps({"listing_id": 42}).encode()

    with patch("godslayer_ml.consumer.process_listing") as process_listing:
        listing_id = handle_message(
            channel, method, None, body, api_base_url="http://api.example.com", ollama_url="http://ollama.example.com"
        )

    assert listing_id == 42
    process_listing.assert_called_once_with(42, "http://api.example.com", "http://ollama.example.com")
    channel.basic_ack.assert_called_once_with(delivery_tag=1)


def test_handle_message_retries_a_transient_failure_and_acks_once_it_succeeds():
    channel = Mock()
    method = Mock(delivery_tag=1)
    body = json.dumps({"listing_id": 42}).encode()

    with (
        patch(
            "godslayer_ml.consumer.process_listing",
            side_effect=[ConnectionError("web unreachable"), None],
        ) as process_listing,
        patch("tenacity.nap.time.sleep") as sleep,
    ):
        listing_id = handle_message(
            channel, method, None, body, api_base_url="http://api.example.com", ollama_url="http://ollama.example.com"
        )

    assert listing_id == 42
    assert process_listing.call_count == 2
    sleep.assert_called_once()
    channel.basic_ack.assert_called_once_with(delivery_tag=1)
    channel.basic_publish.assert_not_called()


def test_handle_message_sends_to_the_dead_queue_once_retries_are_exhausted():
    channel = Mock()
    method = Mock(delivery_tag=1)
    body = json.dumps({"listing_id": 42}).encode()

    with (
        patch(
            "godslayer_ml.consumer.process_listing", side_effect=ConnectionError("web unreachable")
        ) as process_listing,
        patch("tenacity.nap.time.sleep") as sleep,
    ):
        listing_id = handle_message(
            channel, method, None, body, api_base_url="http://api.example.com", ollama_url="http://ollama.example.com"
        )

    assert listing_id == 42
    assert process_listing.call_count == MAX_ATTEMPTS
    assert sleep.call_count == MAX_ATTEMPTS - 1
    channel.basic_publish.assert_called_once_with(exchange="", routing_key=DEAD_QUEUE_NAME, body=body)
    channel.basic_ack.assert_called_once_with(delivery_tag=1)


def test_handle_message_sends_a_permanent_failure_straight_to_the_dead_queue_without_retrying():
    channel = Mock()
    method = Mock(delivery_tag=1)
    body = json.dumps({"listing_id": 42}).encode()
    not_found = requests.exceptions.HTTPError()
    not_found.response = Mock(status_code=404)

    with (
        patch("godslayer_ml.consumer.process_listing", side_effect=not_found) as process_listing,
        patch("tenacity.nap.time.sleep") as sleep,
    ):
        listing_id = handle_message(
            channel, method, None, body, api_base_url="http://api.example.com", ollama_url="http://ollama.example.com"
        )

    assert listing_id == 42
    process_listing.assert_called_once()
    sleep.assert_not_called()
    channel.basic_publish.assert_called_once_with(exchange="", routing_key=DEAD_QUEUE_NAME, body=body)
    channel.basic_ack.assert_called_once_with(delivery_tag=1)


def test_is_permanent_failure_treats_4xx_as_permanent():
    not_found = requests.exceptions.HTTPError()
    not_found.response = Mock(status_code=404)

    assert is_permanent_failure(not_found)


def test_is_permanent_failure_treats_5xx_and_other_exceptions_as_retryable():
    server_error = requests.exceptions.HTTPError()
    server_error.response = Mock(status_code=503)

    assert not is_permanent_failure(server_error)
    assert not is_permanent_failure(ConnectionError("web unreachable"))
    assert not is_permanent_failure(KeyError("ram_value"))
