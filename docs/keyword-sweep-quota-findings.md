# Keyword sweep quota findings (2026-11-27) - why the sweep ships disabled

Investigated while deciding `SWEEP_INTERVAL_HOURS` for the thin-`KeywordSweepJob`
release. Conclusion: ship the release with the sweep schedule still off
(`SWEEP_INTERVAL_HOURS` unset, same as production's current state) rather than
turning it on at any interval, daily included. The release itself - thin job,
`KeywordSweeper`/`CandidatePromoter` split, the concurrency/locking fixes from
Codex's reviews - is real, shipped, and not blocked on any of this. This is a
separate, pre-existing problem that enabling the schedule would immediately
collide with.

## What's actually wrong

Three findings, each confirmed directly against production, not inferred:

### 1. Search pagination is still fully unbounded

`Ebay::Search#keyword` walks every page of a keyword's search results with no
cap:

```ruby
while url
  page = JSON.parse get(url)
  summaries.concat page.fetch("itemSummaries", [])
  url = page["next"]
end
```

This was introduced deliberately in `73f97e8` ("Follow eBay's pagination
instead of only ever seeing the first page") and nothing has bounded it since.
Real per-keyword match volume, queried from production (`CandidateSearchKeyword`
counts per active `search_keyword`, 2026-11-27):

| keyword | candidate matches |
|---|---|
| `(dl380,"dl 380") (gen10,...)` | 9,284 |
| `(dl360,"dl 360") (gen10,...)` | 7,621 |
| `(dl380,"dl 380") (gen9,...)` | 4,810 |
| `(dl360,"dl 360") (gen9,...)` | 2,913 |
| `(ml350,"ml 350") (gen10,...)` | 1,421 |
| `(ml350,"ml 350") (gen9,...)` | 1,090 |
| Cisco UCS (4 keywords), `x3650 m5`, Dell R630/R730/R640/R740 (4 keywords) | 0, every one |

At `limit=200` per page, `dl380 gen10` alone is ~47 search-API calls for one
sweep of one keyword. Across all 15 active keywords, one full sweep cycle can
burn deep into the 5,000/day shared Browse API quota from search pagination
alone, before a single detail call for promotion.

### 2. `errorId: 2001` doesn't reliably come back as HTTP 429

Confirmed live against production, same account, same few minutes
(2026-11-27): a plain `q=laptop` search returned a real `429` with
`{"errors":[{"errorId":2001,"domain":"ACCESS","category":"REQUEST","message":"Too many requests.","longMessage":"The request limit has been reached for the resource."}]}`.
A real production `search_keywords` query (the OR-group/exclude-phrase
syntax) returned the **identical error body with HTTP 200** instead.

eBay's own error-code docs say 2001 should always be 429 - this isn't the
documented GraphQL "errors always come back as 200" behavior either, since
Browse is REST. Whatever the cause (query-shape-dependent eBay bug, or an
undocumented edge case), `Ebay::Base#get` only branches on HTTP status code:

```ruby
raise QuotaExceededError, "..." if response.status.code == 429
raise RequestError, "..." unless response.status.success?
response.body.to_s
```

The 200-with-`errors` variant passes both checks and returns as if it were a
real, successful (if empty) response. No exception, no Sentry capture, no
`FailedExecution` row - the sweep just "succeeds" having found nothing for
that keyword, with no signal anywhere that anything went wrong.

### 3. The zero-match keywords are the smoking gun, not a coincidence

The keywords showing zero candidate matches ever (Cisco UCS, `x3650`, Dell
R6xx/R7xx) are exactly the kind of common homelab search terms that should
return real results - and they sort later than the HP keywords in sweep
order. The pattern is consistent with: quota exhausts partway through a sweep
cycle (via finding 1's volume), the *known* 429 path catches some of it, but
finding 2's silent 200 path swallows the rest with zero signal - so whichever
keywords get processed first in a cycle get real data, and everything after
silently gets nothing, cycle after cycle, with nothing in Sentry to show it.

## Why not fix and ship now

These three compound: uncapped volume (1) guarantees quota exhaustion well
within a day's real traffic, and the detection gap (2) means a meaningful
fraction of that exhaustion is currently invisible. Enabling any schedule -
including "just daily" - without fixing at least the detection gap first
would very likely reproduce the original rate-limit crisis (already
documented separately), except partially silently this time, with no alert
to say so. That's worse than the original crisis, not an improvement on it.

Separately, and not blocking anything: there are 251,640
`solid_queue_failed_executions` rows from a job class called
`ListingSearchKeywordLinkJob`, dated 2026-11-25, all
`ActiveRecord::RecordNotFound: Couldn't find Listing`. That class doesn't
exist anywhere in the current codebase - a dead remnant from before this
branch's refactor, never cleaned up because `clear_solid_queue_finished_jobs`
only clears *finished* jobs, not failed ones. Doesn't affect eBay quota, but
it's real DB bloat worth clearing out at some point.

## What fixing this for real would need

1. Make `Ebay::Base#get` check the response body for an `errors` array with
   `errorId: 2001` regardless of HTTP status code - can't trust the status
   code alone for this error family anymore.
2. Bound `Ebay::Search#keyword`'s pagination - either a hard page cap, or
   (better, since `sort: "newlyListed"` is already in use) stop early once a
   page's items are all already-known candidates, since a keyword that's
   been swept before mostly just needs its *new* listings, not a full re-walk
   of everything it's ever matched.
3. Re-run the real per-keyword volume probe after (1) and (2) land, to get an
   honest call-budget estimate before picking a real `SWEEP_INTERVAL_HOURS`
   value.

None of this is started. This doc is the state of the investigation, not a
scoped plan.

## Status

Release ships with the sweep schedule off. Revisit `SWEEP_INTERVAL_HOURS` only
after the three items above are addressed, not on a timeline.
