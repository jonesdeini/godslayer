import json
import signal
from unittest.mock import Mock, patch

import pika
import requests

from godslayer_ml.consumer import (
    DEAD_QUEUE_NAME,
    MAX_ATTEMPTS,
    PREFETCH_COUNT,
    RECONNECT_DELAY_SECONDS,
    handle_message,
    is_permanent_failure,
    run,
)


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


def test_run_registers_sigterm_and_sigint_to_stop_consuming_gracefully():
    connection = Mock()
    channel = Mock()
    connection.channel.return_value = channel

    with (
        patch("godslayer_ml.consumer.connect", return_value=connection),
        patch("godslayer_ml.consumer.signal.signal") as signal_signal,
    ):
        run("amqp://example.com", "http://api.example.com", "http://ollama.example.com")

    registered = {call.args[0] for call in signal_signal.call_args_list}
    assert registered == {signal.SIGTERM, signal.SIGINT}


def test_signal_handler_stops_the_currently_active_channel():
    connection = Mock()
    channel = Mock()
    connection.channel.return_value = channel
    captured_handlers = {}

    def fake_signal(sig, handler):
        captured_handlers[sig] = handler

    def start_consuming_then_signal():
        captured_handlers[signal.SIGTERM](signal.SIGTERM, None)

    channel.start_consuming.side_effect = start_consuming_then_signal

    with (
        patch("godslayer_ml.consumer.connect", return_value=connection),
        patch("godslayer_ml.consumer.signal.signal", side_effect=fake_signal),
    ):
        run("amqp://example.com", "http://api.example.com", "http://ollama.example.com")

    channel.stop_consuming.assert_called_once()


def test_run_sets_a_prefetch_limit_so_a_reconnect_cannot_grab_the_whole_backlog():
    connection = Mock()
    channel = Mock()
    connection.channel.return_value = channel

    with (
        patch("godslayer_ml.consumer.connect", return_value=connection),
        patch("godslayer_ml.consumer.signal.signal"),
    ):
        run("amqp://example.com", "http://api.example.com", "http://ollama.example.com")

    channel.basic_qos.assert_called_once_with(prefetch_count=PREFETCH_COUNT)


def test_run_reconnects_after_losing_the_connection_to_rabbitmq():
    connection1, channel1 = Mock(), Mock()
    connection2, channel2 = Mock(), Mock()
    connection1.channel.return_value = channel1
    connection2.channel.return_value = channel2
    channel1.start_consuming.side_effect = pika.exceptions.StreamLostError("boom")
    channel2.start_consuming.return_value = None

    with (
        patch("godslayer_ml.consumer.connect", side_effect=[connection1, connection2]) as connect_mock,
        patch("godslayer_ml.consumer.signal.signal"),
        patch("godslayer_ml.consumer.time.sleep") as sleep,
    ):
        run("amqp://example.com", "http://api.example.com", "http://ollama.example.com")

    assert connect_mock.call_count == 2
    sleep.assert_called_once_with(RECONNECT_DELAY_SECONDS)
    connection1.close.assert_called_once()
    connection2.close.assert_called_once()


def test_run_does_not_reconnect_once_a_stop_signal_has_been_received():
    connection = Mock()
    channel = Mock()
    connection.channel.return_value = channel
    captured_handlers = {}

    def fake_signal(sig, handler):
        captured_handlers[sig] = handler

    def start_consuming_then_lose_connection():
        captured_handlers[signal.SIGTERM](signal.SIGTERM, None)
        raise pika.exceptions.AMQPConnectionError("boom")

    channel.start_consuming.side_effect = start_consuming_then_lose_connection

    with (
        patch("godslayer_ml.consumer.connect", return_value=connection) as connect_mock,
        patch("godslayer_ml.consumer.signal.signal", side_effect=fake_signal),
        patch("godslayer_ml.consumer.time.sleep") as sleep,
    ):
        run("amqp://example.com", "http://api.example.com", "http://ollama.example.com")

    connect_mock.assert_called_once()
    sleep.assert_not_called()
