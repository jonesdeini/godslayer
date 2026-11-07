from unittest.mock import Mock, patch

from godslayer_ml.api_client import fetch_listing, fetch_listing_labels, post_determination


def test_fetch_listing_gets_the_listing_by_id_from_the_configured_base_url():
    response = Mock(status_code=200)
    response.json.return_value = {"id": 42, "title": "A server"}
    response.raise_for_status.return_value = None

    with patch("godslayer_ml.api_client.requests.get", return_value=response) as get:
        listing = fetch_listing(42, "http://api.example.com")

    get.assert_called_once_with("http://api.example.com/api/listings/42", timeout=30)
    assert listing == {"id": 42, "title": "A server"}


def test_fetch_listing_labels_gets_all_labels_from_the_configured_base_url():
    response = Mock(status_code=200)
    response.json.return_value = [
        {"listing_id": 1, "ebay_item_id": "v1|1|0", "title": "A server", "label": "computer", "model": "claude"}
    ]
    response.raise_for_status.return_value = None

    with patch("godslayer_ml.api_client.requests.get", return_value=response) as get:
        labels = fetch_listing_labels("http://api.example.com")

    get.assert_called_once_with("http://api.example.com/api/listing_labels", timeout=30)
    assert labels == [
        {"listing_id": 1, "ebay_item_id": "v1|1|0", "title": "A server", "label": "computer", "model": "claude"}
    ]


def test_post_determination_posts_to_the_listings_nested_endpoint():
    response = Mock(status_code=201)
    response.json.return_value = {"id": 1, "field": "ram", "verdict": "mismatch"}
    response.raise_for_status.return_value = None

    with patch("godslayer_ml.api_client.requests.post", return_value=response) as post:
        result = post_determination(
            42,
            "http://api.example.com",
            field="ram",
            verdict="mismatch",
            claimed_value=16,
            claimed_unit="GB",
            photo_value=32,
            photo_unit="GB",
            listing_image_id=7,
        )

    post.assert_called_once_with(
        "http://api.example.com/api/listings/42/determinations",
        json={
            "determination": {
                "field": "ram",
                "verdict": "mismatch",
                "claimed_value": 16,
                "claimed_unit": "GB",
                "photo_value": 32,
                "photo_unit": "GB",
                "listing_image_id": 7,
            }
        },
        timeout=30,
    )
    assert result == {"id": 1, "field": "ram", "verdict": "mismatch"}
