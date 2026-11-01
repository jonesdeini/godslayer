UNIT_TO_MB = {"MB": 1, "MIB": 1, "GB": 1024, "GIB": 1024}

DEFAULT_TOLERANCE_PCT = 10


def to_mb(value: float | None, unit: str | None) -> float | None:
    if value is None or unit is None:
        return None
    factor = UNIT_TO_MB.get(unit.upper())
    if factor is None:
        return None
    return value * factor


def compare_ram(claimed: dict, photo: dict, tolerance_pct: float = DEFAULT_TOLERANCE_PCT) -> dict:
    claimed_mb = to_mb(claimed.get("ram_value"), claimed.get("ram_unit"))
    photo_mb = to_mb(photo.get("ram_value"), photo.get("ram_unit"))

    if claimed_mb is None or photo_mb is None:
        return {"verdict": "no_evidence", "claimed_mb": claimed_mb, "photo_mb": photo_mb}

    diff_pct = abs(claimed_mb - photo_mb) / claimed_mb * 100
    verdict = "match" if diff_pct <= tolerance_pct else "mismatch"
    return {"verdict": verdict, "claimed_mb": claimed_mb, "photo_mb": photo_mb, "diff_pct": diff_pct}
