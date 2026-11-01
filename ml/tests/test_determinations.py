from godslayer_ml.determinations import compare_ram, to_mb


def test_to_mb_converts_gb_as_binary_gib():
    assert to_mb(112, "GB") == 114688


def test_to_mb_leaves_mb_as_is():
    assert to_mb(114688, "MB") == 114688


def test_to_mb_returns_none_for_missing_value_or_unit():
    assert to_mb(None, "GB") is None
    assert to_mb(128, None) is None


def test_compare_ram_flags_the_real_motivating_mismatch():
    claimed = {"ram_value": 128, "ram_unit": "GB"}
    photo = {"ram_value": 114688, "ram_unit": "MB"}

    result = compare_ram(claimed, photo)

    assert result["verdict"] == "mismatch"
    assert result["claimed_mb"] == 131072
    assert result["photo_mb"] == 114688


def test_compare_ram_matches_when_claim_is_accurate():
    claimed = {"ram_value": 112, "ram_unit": "GB"}
    photo = {"ram_value": 114688, "ram_unit": "MB"}

    result = compare_ram(claimed, photo)

    assert result["verdict"] == "match"
    assert result["diff_pct"] == 0


def test_compare_ram_reports_no_evidence_when_either_side_is_missing():
    assert compare_ram({"ram_value": None, "ram_unit": None}, {"ram_value": 114688, "ram_unit": "MB"})["verdict"] == "no_evidence"
    assert compare_ram({"ram_value": 128, "ram_unit": "GB"}, {"ram_value": None, "ram_unit": None})["verdict"] == "no_evidence"
