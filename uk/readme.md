because of brexit and laziness the uk doesn't have data in a sane structured format

will deakin OCR'd some pdfs and with some luck we ought to be able to join it to the centre line model


do run `git submodule update --init --recursive` to get the data


todo:

- copy and concat all W[x] gauge TSVs using head -n1 grepped for W7 for each region
- rename M/Ch to M/Ch and M_end/Ch_end
- convert to decimal miles
- consolidate into a single CSV with all possible gauges as columns
    - annoyingly it is _not_ a strict hierarchy. :(
- draw the rest of the owl. spatial join. manually transcribe gauge polygons to WKT
