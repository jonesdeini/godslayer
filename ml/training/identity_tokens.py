import re

_PAREN_GROUP = re.compile(r"\(([^)]*)\)")


def extract_identity_tokens(phrases: list[str]) -> set[str]:
    """Parses search_keywords.phrase strings (OR-groups, quoted spacing
    variants, e.g. (r630,"r 630") (dell,poweredge)) into the atomic,
    single-word tokens that actually appear in a listing title, for
    exclusion from the title classifier's learned vocabulary.

    Deliberately drops quoted multi-word variants (e.g. "r 630") rather
    than adding their individual words as stop words - a bare "630" risks
    stripping an unrelated spec elsewhere in a title, for the rare benefit
    of catching a seller who wrote the model number with a space."""
    tokens: set[str] = set()
    for phrase in phrases:
        for group in _PAREN_GROUP.findall(phrase):
            for term in group.split(","):
                _add_token(tokens, term)
        for term in _PAREN_GROUP.sub(" ", phrase).split():
            _add_token(tokens, term)
    return tokens


def _add_token(tokens: set[str], term: str) -> None:
    term = term.strip().strip('"').strip().lower()
    if term and " " not in term:
        tokens.add(term)
