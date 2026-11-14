from training.identity_tokens import extract_identity_tokens


def test_extracts_or_group_alternatives_dropping_quoted_spaced_variants():
    tokens = extract_identity_tokens(['(dl380,"dl 380") (gen9,"gen 9",g9,"g 9")'])

    assert tokens == {"dl380", "gen9", "g9"}


def test_extracts_brand_terms_alongside_a_model_number_group():
    tokens = extract_identity_tokens(['(r630,"r 630") (dell,poweredge)'])

    assert tokens == {"r630", "dell", "poweredge"}


def test_extracts_terms_both_inside_and_outside_parens():
    tokens = extract_identity_tokens(["(ucs,cisco) c220 m4"])

    assert tokens == {"ucs", "cisco", "c220", "m4"}


def test_extracts_plain_space_separated_terms_with_no_parens_at_all():
    tokens = extract_identity_tokens(["x3650 m5"])

    assert tokens == {"x3650", "m5"}


def test_merges_tokens_across_multiple_phrases():
    tokens = extract_identity_tokens(['(r630,"r 630") (dell,poweredge)', "x3650 m5"])

    assert tokens == {"r630", "dell", "poweredge", "x3650", "m5"}


def test_returns_an_empty_set_for_no_phrases():
    assert extract_identity_tokens([]) == set()


def test_splits_hyphenated_terms_into_the_pieces_tfidf_will_actually_tokenize():
    tokens = extract_identity_tokens(["e5-2670"])

    assert tokens == {"e5-2670", "e5", "2670"}
