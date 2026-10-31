from unittest.mock import Mock, patch

from godslayer_ml.api_client import fetch_listing


def test_fetch_listing_gets_the_listing_by_id_from_the_configured_base_url():
    response = Mock(status_code=200)
    response.json.return_value = {"id": 42, "title": "A server"}
    response.raise_for_status.return_value = None

    with patch("godslayer_ml.api_client.requests.get", return_value=response) as get:
        listing = fetch_listing(42, "http://api.example.com")

    get.assert_called_once_with("http://api.example.com/api/listings/42", timeout=30)
    assert listing == {"id": 42, "title": "A server"}
