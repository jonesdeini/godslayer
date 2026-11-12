# Listing label fixtures

`listing_labels.json.gz` and `listing_label_predictions.json.gz` match `GET
/api/listing_labels`'s shape: gzipped JSON arrays of rows with
`listing_id`, `ebay_item_id`, `title`, `label`, and `model`. Gzipped so the
real titles don't render in a PR diff or show up in GitHub code search -
not for repo size, since git already compresses stored blobs to about the
same size gzip does.

Both are a real, disjoint, stratified snapshot pulled from production's
`listing_labels` table (2026-11-12) - not handwritten or synthetic.
`listing_labels.json.gz` holds 457 rows (382 computer / 75 part) for
training; `listing_label_predictions.json.gz` holds 12 held out (6/6) for
the "does it generalize to unseen titles" check, with no title overlap
between the two. `model` is `gemini-3.1-flash-lite` throughout - the real
labeling model, not a fixture marker. One exact duplicate title existed
across two different production listings; the training-side copy was
dropped so the held-out copy stays genuinely unseen instead of being
trivially memorized.

These fixtures test the Rails response format, training, export, and real
held-out predictions - a real snapshot, not a live benchmark. The actual
`listing_labels` table keeps growing past what's captured here; resample it
if a new failure mode shows up that this snapshot doesn't represent, not
on a schedule just because the table grew.
