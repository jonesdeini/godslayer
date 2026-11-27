# Keyword join consolidation (deferred)

While fixing a keyword-attribution bug on PR #66 (Codex's Finding 4), we
considered eliminating the duplication behind it entirely - one join table
instead of two that have to be kept in sync - and actually started
implementing it before reverting. The idea is sound; the timing isn't.
Checked against real production data before deciding, not assumed: it would
have silently broken identity-token exclusion for 100% of today's real
training labels. Kept Codex's minimal fix on the PR instead. This doc is the
deferred idea, not a decision to act on.

## The idea

Right now, a keyword match gets recorded in two places that have to stay in
sync by hand: `CandidateSearchKeyword` (always written, every encounter) and
`ListingSearchKeyword` (only ever written inside promotion, or - after the
Finding 4 fix - also written directly once `listing_id` is already known).
Every place that writes one has to remember to write the other correctly,
for the same underlying fact.

The cleaner shape: `Listing has_many :search_keywords, through:
:listing_candidate` (which already exists as a `has_one`, added for the
`listing_id` work), reading straight through `ListingCandidate`'s own
`candidate_search_keywords`. One table, one place a match ever gets
written, nothing to keep in sync because there's only one copy of the
fact. `ListingSearchKeyword` and `candidate_promoter.rb`'s matching write
go away entirely.

## Why not now

`GET /api/listing_labels` derives `search_keyword_phrases` from
`Listing#search_keywords`, and `ml/training/train_classifier.py`'s
`collect_identity_tokens()` depends on that field to know which brand/model
words to exclude from the learned vocabulary - the mechanism that already
caused one real leakage bug (identity tokens scoped per-listing instead of
globally, caught by Codex, fixed same day).

Checked directly against the live API before deciding, not assumed:

```
total labels: 1794
labels with search_keyword_phrases populated via the current mechanism: 1794 (100%)
```

Every real training label today is against a listing that predates
`listing_candidates` entirely - none of them have a `ListingCandidate` to
read through. Switching `Listing#search_keywords` to derive `through:
:listing_candidate` would have returned empty for all 1,794 of them, zeroing
out `collect_identity_tokens()`'s entire input and silently reintroducing
the exact leakage bug that was already found and fixed once.

## What "carry the labels forward" would require

1. Backfill a synthetic `ListingCandidate` for every pre-candidate-system
   `Listing` - `title`, `ebay_item_id`, etc. are already sitting on the
   `Listing` itself, so this is mechanical, not blocked by any schema
   constraint.
2. Migrate each one's existing `listing_search_keywords` rows into
   `candidate_search_keywords` rows pointing at that synthetic candidate,
   then drop `listing_search_keywords`.
3. Seed each synthetic candidate's `CandidateClassification` from real
   data, not leave it blank - a candidate with no classification looks
   identical to the Finding-1 bug ("exists, never classified"), so leaving
   ~65K of them unclassified would make every one of them look due for
   reclassification the moment a sweep re-discovers the real item, burning
   detail calls on things we already have a `Listing` for. This isn't
   starting from scratch: the real backfill-classification run from
   earlier this session (45,420 computer / 20,099 part, real titles, the
   real trained model) already has the actual verdicts needed to seed this
   step.

None of this is started. It's the shape the work would take if it's ever
worth doing, not a plan that's been scoped or estimated.

## Status

Deferred, not scheduled. Not part of PR #66 (which ships Codex's minimal fix
instead) or anything else currently in flight. Revisit only if the two-table
duplication becomes an actual recurring pain point, not on a timeline.
