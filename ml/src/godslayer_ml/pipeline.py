import logging

from godslayer_ml.api_client import fetch_listing
from godslayer_ml.images import download
from godslayer_ml.ocr import read_text

logger = logging.getLogger(__name__)


def process_listing(listing_id: int, api_base_url: str) -> None:
    listing = fetch_listing(listing_id, api_base_url)

    for image in listing.get("images", []):
        text = read_text(download(image["url"]))
        logger.info("listing_id=%s image_id=%s ocr_text=%r", listing_id, image["id"], text)
