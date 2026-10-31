from unittest.mock import patch

from godslayer_ml.pipeline import process_listing


def test_process_listing_downloads_and_ocrs_every_image():
    listing = {
        "id": 42,
        "images": [
            {"id": 1, "url": "http://rails.example.com/blobs/1"},
            {"id": 2, "url": "http://rails.example.com/blobs/2"},
        ],
    }

    with (
        patch("godslayer_ml.pipeline.fetch_listing", return_value=listing) as fetch,
        patch("godslayer_ml.pipeline.download", side_effect=[b"bytes-1", b"bytes-2"]) as download,
        patch("godslayer_ml.pipeline.read_text", side_effect=["text one", "text two"]) as read_text,
    ):
        process_listing(42, "http://api.example.com")

    fetch.assert_called_once_with(42, "http://api.example.com")
    assert download.call_args_list[0].args == ("http://rails.example.com/blobs/1",)
    assert download.call_args_list[1].args == ("http://rails.example.com/blobs/2",)
    assert read_text.call_args_list[0].args == (b"bytes-1",)
    assert read_text.call_args_list[1].args == (b"bytes-2",)


def test_process_listing_does_nothing_when_there_are_no_images():
    with (
        patch("godslayer_ml.pipeline.fetch_listing", return_value={"id": 42, "images": []}),
        patch("godslayer_ml.pipeline.download") as download,
        patch("godslayer_ml.pipeline.read_text") as read_text,
    ):
        process_listing(42, "http://api.example.com")

    download.assert_not_called()
    read_text.assert_not_called()
