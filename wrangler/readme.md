# Loading gauge maps

`gauge_geometries.sql` compares manually transcribed gauge polygons and calculates their areas.
The model uses only the right half of each upper profile, extended down to the baseline.
Compatibility tables use polygon coverage; maps show profile area.

## Gauge tables

Use the DuckDB CLI with the spatial extension. Run from the repository root:

```sh
duckdb -bail -f gauge_geometries.sql
```

Outputs:

- `gauge_areas.csv`: half-profile areas in square millimetres.
- `train_to_possible_tracks.csv`: track profiles that cover each vehicle profile.
- `track_to_possible_trains.csv`: vehicle profiles covered by each track profile.
- `track_to_biggest_international_train.csv`: covered international profile with the fewest compatible track profiles.
- `polygons.json`: profile coordinates in millimetres.

DE1, DE2, S, EBV1, EBV2, and GEE10 include estimated or uncertain geometry.
Sources and qualifications are recorded beside the definitions in `gauge_geometries.sql`.

## XML map export

Use Julia 1.11.5 and the supplied lookup CSV files.
Download ERA XML datasets from the [dataset explorer](https://data-interop.era.europa.eu/dataset-explorer).
Extract archives and put the XML files in `wrangler/data/` with a `.xml` suffix.
The export also reads the supplied `uk/uk.parquet`; see [UK gauge data](../uk/readme.md) to rebuild it.

Run from the repository root:

```sh
julia --project=wrangler -e 'using Pkg; Pkg.instantiate()'
(cd wrangler && julia --project=. wrangler.jl)
```

The script writes H3 CSV and metadata under `wrangler/out/loading_gauge/`, plus `wrangler/loading_gauges.geojson`.
To view H3, copy `wrangler/out/loading_gauge/` to [H3-MON](https://github.com/bovine3dom/H3-MON)'s `www/data/` and open `?data=loading_gauge/YYYY-MM-DD.csv`.
H3 resolution is 5. Each cell uses section start points and the largest known profile area, relative to GC.
GeoJSON joins endpoints and reports approximate full-profile area in square metres.
Missing coordinates, gauge labels, and areas are omitted.
