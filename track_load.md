# Track load data

## ERA properties

`era:LoadCapability` is a class, not a property.
A track uses `era:trackLoadCapability` to refer to one or more instances of this class.
Each instance has two parts:

- `era:loadCapabilityLineCategory`: the load model, such as C4 or D4.
- `era:loadCapabilitySpeed`: the permitted speed for that load model at the weakest point of the track.

For example, C4/120 and D4/90 are two records. They do not mean D4/120.
Do not replace these speeds with `era:maximumPermittedSpeed`.

`era:lineCategory` has a different purpose.
It gives the Technical Specification for Interoperability (TSI) traffic classification, such as P2 or F1.
It does not give the reported load capability.
Do not use it to fill missing load data.

## Run or resume the export

```sh
python3 dump_loads.py
```

Use Python 3.8 or newer and curl on Linux or macOS. DuckDB is optional. No Python packages are required.
The script writes `loads.csv`. If DuckDB is installed, it also runs `wrangler_load.sql` to make `loads.parquet`.
Use `--csv-only` to skip DuckDB. Any existing Parquet file then stays unchanged.

The script downloads the section IDs once and checks their count against ERA.
It sorts the IDs locally and caches them in `.load-cache/`.
Each request inserts up to 500 IDs into `query_load.sparql` with `VALUES`.
There is no `OFFSET` and no outer row limit. Empty batches do not stop the download.
Each batch keeps all reported load pairs for its sections.

The script retries transient HTTP errors and shows progress.
Run the same command after a failure or interruption. Completed batches are not downloaded again.
Existing output files stay unchanged until the new export is ready.
One cache can be used by only one downloader at a time.

For a fresh export, use a new cache directory:

```sh
python3 dump_loads.py --cache-dir .load-cache/new-run
```

Use `--batch-size 250` for smaller batches and `--timeout 120` for a longer HTTP timeout.
Changes to the endpoint, query, or batch size require a new cache directory.
Use `--output-dir DIR` to select the output directory.

The cached ID list is fixed. ERA values can still change between requests.
The export is not an atomic snapshot. A resumed export can contain values downloaded on different dates.
The full query without batching timed out during a download attempt.

## Export rules

`query_load.sparql` exports running tracks within sections of line.
It does not require a gauge, load value, category label, or endpoint geometry.
Missing data stays unknown. It does not mean zero load or permission to operate.

The query reads `era:hasPart` and the old `era:track` links.
It resolves direct and canonical operational-point links.
It reads geometry directly or through `era:netReference`.
It also reads parameters from `era:belongsTo` sets and their `era:subsetOf` parent sets.
Direct and shared values stay separate. The query does not select an override.

The export keeps these fields:

- `sol`, `track`: source identifiers.
- `startWKT`, `endWKT`: endpoint geometry, when available.
- `loadSource`: the track or shared set that reports the value.
- `loadCapability`: the identifier for the category/speed pair.
- `loadCategory`, `loadCategoryCode`, `loadCategoryLabel`: the category URI, code, and label.
- `loadSpeed`: the reported speed, without conversion.

`wrangler_load.sql` keeps all these raw fields in `loads.parquet`.
It adds coordinates, `load_category`, an integer `load_speed`, and `load_speed_unit`.
RA1 through RA10 use mph. The other listed load models use km/h.
The unit comes from the category code, with the English or untagged label as a fallback.
Unknown codes keep a null unit. Invalid speeds keep a null integer value.

The SQL accepts plain WKT or WKT with the OGC 1.3 CRS84 prefix.
Invalid geometry and other coordinate systems keep null coordinates. The raw WKT remains available.

The queries do not filter validity periods.
Do not treat historical graph data as current permission to operate.
The query does not read the old `era:loadCapability` SKOS values.

## Map decisions

Keep all reported pairs until you select a display rule:

1. Select a minimum speed. Show load models that permit at least that speed.
   Convert mph to km/h before you compare speeds.
2. Select the measure: category, axle mass, or mass per unit length.
   Axle mass alone does not describe the full load model.
   Do not rank category URI numbers or assume that RA and EN categories use the same scale.
3. Select how to show parallel tracks: all alternatives, or one selected track.
   Join gauges and loads on both `sol` and `track` before you combine records by location.
   Use raw `out.csv`. The existing gauge summaries remove track identifiers.
   A gauge from one track and a load value from another do not describe one usable track.

No category ranking or mass conversion is included yet.
RA, HS17, and D4xL remain distinct codes.
ERA states that EN 15528 categories do not apply to TSI classes P1520/F1520 or P1600/F1600.

## Tests

```sh
uv run --with-requirements tests/requirements.txt python -m unittest discover -s tests -v
```

The tests use a local RDF fixture. The Parquet test also runs if the DuckDB CLI is installed.

## Sources

- [ERA ontology v4.0.0](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/v4.0.0/ontology.ttl)
- [ERA load-category vocabulary](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/main/era-skos/era-skos-LoadCapabilityLineCategories.ttl)
- [ERA TSI line-category vocabulary](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/main/era-skos/era-skos-LineCategories.ttl)
