import requests


def fetch_listing(listing_id: int, base_url: str) -> dict:
    response = requests.get(f"{base_url}/api/listings/{listing_id}", timeout=30)
    response.raise_for_status()
    return response.json()


def fetch_listing_labels(base_url: str) -> list[dict]:
    response = requests.get(f"{base_url}/api/listing_labels", timeout=30)
    response.raise_for_status()
    return response.json()


def fetch_search_keywords(base_url: str) -> list[dict]:
    response = requests.get(f"{base_url}/api/search_keywords", timeout=30)
    response.raise_for_status()
    return response.json()


def post_determination(listing_id: int, base_url: str, **determination) -> dict:
    response = requests.post(
        f"{base_url}/api/listings/{listing_id}/determinations",
        json={"determination": determination},
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


def post_title_classifier_model(base_url: str, **title_classifier_model) -> dict:
    response = requests.post(
        f"{base_url}/api/title_classifier_models",
        json={"title_classifier_model": title_classifier_model},
        timeout=30,
    )
    response.raise_for_status()
    return response.json()
