# route_tchooseur

Extract railway loading gauges and load limits from the European Union Agency for Railways (ERA).
Export H3 and GeoJSON maps.
Loading gauge describes vehicle cross section. Load limits describe axle mass and mass per metre.

## Track load maps

Requirements: Linux or macOS, Python 3.8 or newer, curl, and the [DuckDB 1.5 CLI](https://duckdb.org/install/).
Put `duckdb` on `PATH`. DuckDB downloads the spatial and H3 extensions on first use.
No Python packages are required.

Run from the repository root:

```sh
python3 dump_loads.py
python3 export_load_maps.py
```

The download produces `loads.csv` and `loads.parquet`. Run it again to resume an interrupted download.
The map export writes `out/track-loads/`.

Copy this directory to [H3-MON](https://github.com/bovine3dom/H3-MON)'s `www/data/track-loads/` directory.
Open H3-MON with `?data=track-loads/index.csv`.
Select the result, criterion, threshold, and H3 or GeoJSON format.

See [Track load data](track_load.md) for download options, fields, units, and map rules.

## Gauges, track speeds, and platforms

Export an ERA query as CSV:

```sh
curl --fail --show-error -H 'Accept: text/csv' \
    -H 'Content-Type: application/sparql-query' \
    --data-binary @query.sparql --output out.csv \
    https://rinf.data.era.europa.eu/api/sparql
duckdb -bail -f wrangler.sql
```

Use these query, output, and processing files for each dataset:

| Dataset | Query | CSV output | Processing |
| --- | --- | --- | --- |
| Loading gauges | `query.sparql` | `out.csv` | `wrangler.sql` |
| Track speeds | `query_speed.sparql` | `speeds.csv` | `wrangler_speed.sql` |
| Platforms | `query_platforms.sparql` | `platforms.csv` | `wrangler_platforms.sql` |

Gauge processing writes `out.parquet` and `gauge_labels.csv`. Its section summaries do not retain track identifiers.
The section summary selects the lowest numeric gauge code.
Speed processing writes `speeds.parquet` in km/h.
For platforms, first run `mkdir -p out/platforms`. Processing writes maximum height and length per H3 cell there.
Platform height is in millimetres; usable length is in metres. The maxima can come from different platform edges.
Track speed is separate from the speed reported for a load category.

See [Loading gauge maps](wrangler/readme.md) for gauge geometry and XML map exports.
See [UK gauge data](uk/readme.md) for the Network Rail dataset.

## Tests

```sh
python3 -m unittest discover -s tests -v
```

Put `duckdb` on `PATH`, or set `DUCKDB` to its executable path.
DuckDB tests are skipped if no CLI is available. Node.js enables the control-expression tests.

## Licence

The code uses the [BSD-2-Clause licence](LICENSE).
Source data remain subject to their publishers' terms.
