# Track load data

The European Union Agency for Railways (ERA) reports each running track's load category with its speed.
C4/120 and D4/90 are separate records; they do not mean D4/120.
`era:lineCategory` gives traffic classifications such as P2 or F1.
The general track speed limit and the category's speed are separate values.

## Download

Use Python 3.8 or newer and curl on Linux or macOS. Run from the repository root:

```sh
python3 dump_loads.py
```

The script writes `loads.csv`. With `duckdb` on `PATH`, it also produces `loads.parquet` through `wrangler_load.sql`.
Use `--csv-only` to skip Parquet conversion; an existing Parquet file then stays unchanged.
To convert a CSV export separately:

```sh
duckdb -bail -f wrangler_load.sql
```

Downloads use cached batches of 500 section IDs in `.load-cache/`.
Run the same command to resume. Only one downloader can use a cache at a time.
Use a new `--cache-dir` for fresh data or after changes to the endpoint, query, or batch size.
Use `--output-dir` to change the destination, `--batch-size` to change batch size, and `--timeout` to change the HTTP timeout.
Completed output files remain unchanged until the export is ready.
Resumed exports can combine records from different dates.

Direct and shared parameter values remain separate records.
The CSV retains tracks with missing load values, labels, or geometry.
Validity periods are not filtered.

## Fields and units

`loads.csv` contains:

| Fields | Meaning |
| --- | --- |
| `sol`, `track` | Section and track identifiers |
| `startWKT`, `endWKT` | Endpoint geometry |
| `loadSource` | Track or shared set that reports the value |
| `loadCapability` | Identifier for the category/speed pair |
| `loadCategory`, `loadCategoryCode`, `loadCategoryLabel` | Category URI, code, and label |
| `loadSpeed` | Reported speed, without conversion |

`loads.parquet` retains these fields and adds:

| Fields | Meaning |
| --- | --- |
| `start_lon`, `start_lat`, `end_lon`, `end_lat` | WGS84 coordinates in degrees |
| `load_category` | Category code, with label as a fallback |
| `load_speed`, `load_speed_unit` | Integer speed and its unit |
| `load_speed_kmh` | Speed in km/h |
| `max_axle_load_t` | Mass per axle, in metric tonnes |
| `max_mass_per_m_t` | Mass per metre, in metric tonnes per metre |

RA1–RA10 use mph; other supported models use km/h. One mph equals 1.609344 km/h.
Unknown units and invalid speeds remain null.
Plain WKT and OGC CRS84 WKT are accepted. Unsupported coordinate systems and invalid geometry give null coordinates.

Mass limits use UIC categories A, B1, B2, C2, C3, C4, D2, D3, D4, E4, and E5.
D4 gives 22.5 t/axle and 8 t/m; E5 gives 25 t/axle and 8.8 t/m.
Mass per metre includes the wagon and its load, divided by its length over uncompressed buffers.
RA, HS17, D4xL, and unknown categories have no numeric mass mapping.

## Maps

Use the DuckDB CLI with spatial and H3 extension support:

```sh
python3 export_load_maps.py
```

Defaults: input `loads.parquet`, output `out/track-loads/`, H3 resolution 5, and URL prefix `data/track-loads`.
Use `--input`, `--output-dir`, `--resolution`, `--url-prefix`, or `--duckdb` to change these settings.

Each query has an H3 CSV file in `h3/`, a GeoJSON file in `geojson/`, and matching `.json` metadata.
`manifest.json` lists thresholds and files, the source hash, and geometry rules.
A `p` replaces the decimal point in file names:

| File name | Result |
| --- | --- |
| `speed-for-axle-22p5t` | Maximum speed for 22.5 t/axle |
| `speed-for-per-m-8tpm` | Maximum speed for 8 t/m |
| `max-axle-at-120kmh` | Maximum axle load at 120 km/h |
| `max-per-m-at-120kmh` | Maximum mass per metre at 120 km/h |

Copy the export to [H3-MON](https://github.com/bovine3dom/H3-MON)'s `www/data/track-loads/` directory.
Open `?data=track-loads/index.csv` to select the result, criterion, threshold, and map format.
The client must support `onchange`, `showIf`, and control `encode` functions.

Each query calculates the maximum compatible answer for each section/track pair before geographic aggregation.
Zero indicates no positive result among the recorded pairs. Unknown results are omitted.
If no known pair fits and an unknown pair could fit, the track is omitted.
The 0 km/h criterion includes recorded zero-speed pairs.

H3 uses section start points and the maximum known track answer in each cell.
GeoJSON uses straight endpoint lines, or a point when only one endpoint is valid.

Axle load and mass per metre are independent queries. To combine them, match both limits to the same category/speed pair.
Join load and gauge records on both `sol` and `track`.

## Sources

- [ERA ontology](https://gitlab.com/era-europa-eu/public/interoperable-data-programme/era-ontology/era-ontology/-/blob/v4.0.0/ontology.ttl): `trackLoadCapability`, `loadCapabilityLineCategory`, and `loadCapabilitySpeed`.
- [UNECE wagon marks](https://wiki.unece.org/spaces/TransportSustainableCTUCode/pages/23102009/5+European+rail+wagon+marks), section 5.1.
- [UIC Loading Guidelines, Volume 1, 1 April 2026](https://www.fslogistix.com/content/dam/polologistica/chi-siamo/le-nostre-societa/mercitalia-rail/direttive-per-il-carico--tomo-1---tomo-2/uic_loading_guidelines-volume_1_01.04_2026.pdf), section 3.1.
