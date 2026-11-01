import requests


def fetch_listing(listing_id: int, base_url: str) -> dict:
    response = requests.get(f"{base_url}/api/listings/{listing_id}", timeout=30)
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
