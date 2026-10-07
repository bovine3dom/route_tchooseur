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
`load_speed_kmh` converts this speed to km/h. One mph equals 1.609344 km/h.
Unknown units and invalid speeds give a null `load_speed_kmh`.
This is the speed for the reported load model, not the general track speed limit.

### Numeric load limits

The SQL also adds two numeric fields:

- `max_axle_load_t`: maximum mass per axle, in metric tonnes.
- `max_mass_per_m_t`: maximum mass per unit length, in metric tonnes per metre.

The mapping uses the UIC Loading Guidelines, Volume 1, section 3.1, dated 1 April 2026.
The UNECE page linked in [issue 5](https://github.com/bovine3dom/route_tchooseur/issues/5) describes these measurements.
For example, D4 gives 22.5 t per axle and 8.0 t/m. E5 gives 25.0 t per axle and 8.8 t/m.
Mass per unit length includes the wagon and its load, divided by its length over uncompressed buffers.

The mapping covers A, B1, B2, C2, C3, C4, D2, D3, D4, E4, and E5.
RA, HS17, D4xL, unknown classes, and missing classes keep null mass limits.
Do not treat D4xL as D4 or convert RA numbers to EN classes.

These limits describe reference load models. They do not give vehicle approval.
Axle spacing and axle count can also affect bridge loads.

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

No category ranking is included.
ERA states that EN 15528 categories do not apply to TSI classes P1520/F1520 or P1600/F1600.

### Static H3-MON files

Keep `loads.parquet` as the source table. Generate the display files with:

```sh
python3 export_load_maps.py --output-dir ../H3-MON/www/data/track-loads
```

The script uses the DuckDB CLI with the spatial and H3 extensions. No Python packages are required.
Use `--duckdb PATH` if the CLI is not on `PATH` or at `~/.duckdb/cli/latest/duckdb`.
The default output directory is `out/track-loads`. Use `--url-prefix` if the served path differs from `data/track-loads`.

Each threshold has an H3 CSV file and a GeoJSON file:

| File name | Result |
| --- | --- |
| `speed-for-axle-22p5t` | Maximum speed for a 22.5 t axle load |
| `speed-for-per-m-8tpm` | Maximum speed for 8 t/m |
| `max-axle-at-120kmh` | Maximum axle load at 120 km/h |
| `max-per-m-at-120kmh` | Maximum mass per metre at 120 km/h |

A `p` replaces the decimal point in file names.
H3 files are in `h3/` with a `.csv` suffix. GeoJSON files are in `geojson/` with a `.geojson` suffix.
The current source has five axle thresholds, five mass-per-metre thresholds, and 46 speed thresholds, including 0 km/h.
This gives 102 queries and 204 map files. Each map has a same-name `.json` metadata file.
`manifest.json` records the thresholds, source hash, geometry rule, and H3 resolution.

The queries treat axle mass and mass per metre separately.
They first calculate the best reported answer for each section/track pair.
C4/120 and D4/90 give 90 km/h for a 22.5 t axle load, not 120 km/h.
Zero means that the recorded limits do not meet the selected threshold.
Unknown results are omitted. A track with only unknown data does not produce a zero.
If no known pair fits but an unknown pair could fit, the track is also omitted.
The 0 km/h criterion includes recorded zero-speed class pairs. It does not establish a permitted running speed.

H3 uses section start points at resolution 5, as in `wrangler/wrangler.jl`.
Use `--resolution` to change this value.
Each cell shows the maximum of its known track answers. It does not show the worst track or a continuous route.
GeoJSON joins valid endpoints with a straight line. These lines are approximations, not full track alignments.
A single valid endpoint gives a point. Tracks with no valid endpoint are omitted from GeoJSON.

Open H3-MON with `?data=track-loads/index.csv`.
`index.json` provides three visible query controls: Value shown, Criterion, and Criterion value.
For speed, choose an axle-load or mass-per-metre criterion.
For axle load or mass per metre, the criterion is speed.
Only the applicable criterion and threshold controls are shown. Hidden controls keep their selected values.
The separate Map format control selects H3 or GeoJSON for the same query.
For GeoJSON, open `?data=track-loads/geojson/speed-for-axle-22p5t.geojson`.
H3-MON uses `onchange` to load the selected static file on startup and after each control change.
No map click, map movement, or query server is required.
The other metadata files provide the same controls, with defaults that match the opened map.

These maps do not check both mass requirements together.
For vehicle approval, both requirements must fit the same class/speed pair. Do not combine independent map maxima.

## Tests

```sh
DUCKDB="$HOME/.duckdb/cli/latest/duckdb" python3 -m unittest discover -s tests -v
```

Set `DUCKDB` to the CLI path, or put the CLI on `PATH`.
The tests use temporary CSV and Parquet files.
They check numeric limits, speed units, class/speed pairs, quoted fields, map queries, omitted unknowns, and H3 aggregation.
The tests are skipped if no DuckDB CLI is selected.
If Node.js is available, the tests also check control visibility and file URLs.

## Sources

- [UNECE European rail wagon marks](https://wiki.unece.org/spaces/TransportSustainableCTUCode/pages/23102009/5+European+rail+wagon+marks), section 5.1.
- [UIC Loading Guidelines, Volume 1, 1 April 2026](https://www.fslogistix.com/content/dam/polologistica/chi-siamo/le-nostre-societa/mercitalia-rail/direttive-per-il-carico--tomo-1---tomo-2/uic_loading_guidelines-volume_1_01.04_2026.pdf), section 3.1, page 3-1.
- [H3-MON data format](https://github.com/bovine3dom/H3-MON#data-format).
- [ERA ontology v4.0.0](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/v4.0.0/ontology.ttl)
- [ERA load-category vocabulary](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/main/era-skos/era-skos-LoadCapabilityLineCategories.ttl)
- [ERA TSI line-category vocabulary](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/main/era-skos/era-skos-LineCategories.ttl)
