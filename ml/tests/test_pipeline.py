from unittest.mock import patch

from godslayer_ml.pipeline import find_photo_ram, format_aspects, process_listing


def test_format_aspects_joins_name_value_pairs():
    aspects = [{"name": "RAM Size", "value": "128GB RAM"}, {"name": "Processor", "value": "Xeon E5-2630 v3"}]

    assert format_aspects(aspects) == "RAM Size: 128GB RAM, Processor: Xeon E5-2630 v3"


def test_format_aspects_handles_none_or_empty():
    assert format_aspects(None) == ""
    assert format_aspects([]) == ""


def test_find_photo_ram_stops_at_the_first_image_with_a_hit():
    images = [{"id": 1, "url": "http://a"}, {"id": 2, "url": "http://b"}]

    with (
        patch("godslayer_ml.pipeline.download", return_value=b"bytes") as download,
        patch("godslayer_ml.pipeline.read_text", return_value="ocr text"),
        patch(
            "godslayer_ml.pipeline.extract_photo_ram",
            return_value={"ram_value": 114688, "ram_unit": "MB"},
        ) as extract_photo_ram,
    ):
        result = find_photo_ram(images, "http://ollama.example.com")

    assert result == {"ram_value": 114688, "ram_unit": "MB", "image_id": 1}
    download.assert_called_once_with("http://a")
    extract_photo_ram.assert_called_once_with("ocr text", "http://ollama.example.com")


def test_find_photo_ram_tries_every_image_and_gives_up_with_no_evidence():
    images = [{"id": 1, "url": "http://a"}, {"id": 2, "url": "http://b"}]

    with (
        patch("godslayer_ml.pipeline.download", return_value=b"bytes"),
        patch("godslayer_ml.pipeline.read_text", return_value="ocr text"),
        patch("godslayer_ml.pipeline.extract_photo_ram", return_value={"ram_value": None, "ram_unit": None}) as extract_photo_ram,
    ):
        result = find_photo_ram(images, "http://ollama.example.com")

    assert result == {"ram_value": None, "ram_unit": None, "image_id": None}
    assert extract_photo_ram.call_count == 2


def test_process_listing_extracts_both_sides_and_compares():
    listing = {
        "id": 42,
        "description": "128GB (4x32GB) DDR4",
        "localized_aspects": [{"name": "RAM Size", "value": "128GB RAM"}],
        "images": [{"id": 1, "url": "http://rails.example.com/blobs/1"}],
    }

    with (
        patch("godslayer_ml.pipeline.fetch_listing", return_value=listing),
        patch("godslayer_ml.pipeline.download", return_value=b"bytes"),
        patch("godslayer_ml.pipeline.read_text", return_value="Total System Memory 114688 MB"),
        patch("godslayer_ml.pipeline.extract_claimed_ram", return_value={"ram_value": 128, "ram_unit": "GB"}) as extract_claimed_ram,
        patch("godslayer_ml.pipeline.extract_photo_ram", return_value={"ram_value": 114688, "ram_unit": "MB"}),
        patch("godslayer_ml.pipeline.compare_ram", return_value={"verdict": "mismatch"}) as compare_ram,
        patch("godslayer_ml.pipeline.post_determination") as post_determination,
    ):
        process_listing(42, "http://api.example.com", "http://ollama.example.com")

    extract_claimed_ram.assert_called_once_with("RAM Size: 128GB RAM", "128GB (4x32GB) DDR4", "http://ollama.example.com")
    compare_ram.assert_called_once_with(
        {"ram_value": 128, "ram_unit": "GB"}, {"ram_value": 114688, "ram_unit": "MB", "image_id": 1}
    )
    post_determination.assert_called_once_with(
        42,
        "http://api.example.com",
        field="ram",
        verdict="mismatch",
        claimed_value=128,
        claimed_unit="GB",
        photo_value=114688,
        photo_unit="MB",
        listing_image_id=1,
    )


def test_process_listing_handles_no_images_at_all():
    listing = {"id": 42, "description": None, "localized_aspects": None, "images": []}

    with (
        patch("godslayer_ml.pipeline.fetch_listing", return_value=listing),
        patch("godslayer_ml.pipeline.extract_claimed_ram", return_value={"ram_value": None, "ram_unit": None}),
        patch("godslayer_ml.pipeline.download") as download,
        patch("godslayer_ml.pipeline.post_determination") as post_determination,
    ):
        process_listing(42, "http://api.example.com", "http://ollama.example.com")

    download.assert_not_called()
    post_determination.assert_called_once_with(
        42,
        "http://api.example.com",
        field="ram",
        verdict="no_evidence",
        claimed_value=None,
        claimed_unit=None,
        photo_value=None,
        photo_unit=None,
        listing_image_id=None,
    )
