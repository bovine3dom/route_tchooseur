# UK loading gauges

This dataset joins [Will Deakin's NESA OCR tables](https://github.com/anisotropi4/nesa) to the
[Network Rail centre-line model](https://github.com/openraildata/network-rail-gis).
`elr_to_line_of_route.csv` maps lines of route to Engineer's Line References (ELRs), supplemented by [Geofurlong](https://www.geofurlong.com/lor/tables/).

## Build

Use the DuckDB CLI with the spatial extension. Run from the repository root:

```sh
git submodule update --init uk/network-rail-gis
(cd uk && duckdb -bail -f wrangler.sql)
```

The script reads the supplied `nesa_wrangled/*.csv` and ELR lookup table.
It writes `uk/out.parquet` with gauge flags and geometry, and `uk/uk.parquet` with gauge-labelled endpoint segments.
The XML gauge map exporter uses `uk/uk.parquet`.

To rebuild the gauge CSV files, install fish and [qsv](https://github.com/dathere/qsv), then run:

```sh
git submodule update --init uk/nesa_ocr
(cd uk && fish nesa_gauge_wrangler.fish)
```

## Mapping rules

A line-of-route match applies its gauges to the whole ELR.
Any exact `Y` entry marks a gauge as available. Qualified entries and route-specific notes are not interpreted.
W6 is treated as W6A. Missing geometry is omitted.
