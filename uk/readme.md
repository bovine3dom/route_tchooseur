because of brexit and laziness the uk doesn't have data in a sane structured format

will deakin OCR'd some pdfs and with some luck we ought to be able to join it to the centre line model


do run `git submodule update --init --recursive` to get the data


todo:

- consolidate into a single CSV with all possible gauges as columns
    - annoyingly it is _not_ a strict hierarchy. :(
- manually transcribe gauge polygons to WKT
- pretend each point on the linestring is an operational point for compat with RINF?
