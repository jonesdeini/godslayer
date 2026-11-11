# Listing label fixtures

`listing_labels.json` matches `GET /api/listing_labels`: an array of rows with
`listing_id`, `ebay_item_id`, `title`, `label`, and `model`. It contains 40 whole
machines and 40 standalone components/accessories, including the eight original
training-test titles. Parts deliberately mention the same server brands and
models as complete machines.

These are handwritten, synthetic listing titles with manually assigned labels,
not an export of real eBay listings or the output of a live LLM. IDs and the
`fixture-manual-label` model name identify fixture data. No answer words were
added to the titles to distinguish the classes.

`listing_label_predictions.json` uses the same row shape for separate prediction
examples. None of its titles appears in the training fixture. It retains the
original server and CPU prediction examples and also checks server accessories,
workstations, and machines without drives or an OS.

These fixtures test the Rails response format, training, export, and known
predictions. Passing them does not establish accuracy on real production data;
evaluate that separately on representative, independently labeled listings.
