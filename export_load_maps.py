#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

FAMILIES = [
    ("speed-for-axle", "axle", "max_axle_load_t", "load_speed_kmh", "t", "Speed for {n} t/axle (km/h)"),
    ("speed-for-per-m", "per_m", "max_mass_per_m_t", "load_speed_kmh", "tpm", "Speed for {n} t/m (km/h)"),
    ("max-axle-at", "speed", "load_speed_kmh", "max_axle_load_t", "kmh", "Axle load at {n} km/h (t)"),
    ("max-per-m-at", "speed", "load_speed_kmh", "max_mass_per_m_t", "kmh", "Mass per metre at {n} km/h (t/m)"),
]


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def run_sql(duckdb, sql, structured=False):
    command = [duckdb, "-bail"] + (["-json"] if structured else [])
    result = subprocess.run(command, input=sql, text=True, check=True,
                            capture_output=True, timeout=600)
    return json.loads(result.stdout) if structured else None


def thresholds(duckdb, source):
    fields = {"axle": "max_axle_load_t", "per_m": "max_mass_per_m_t", "speed": "load_speed_kmh"}
    projections = []
    for name, field in fields.items():
        condition = f"isfinite({field}) AND {field} {'>= 0' if name == 'speed' else '> 0'}"
        if name == "speed":
            condition += " AND (max_axle_load_t > 0 OR max_mass_per_m_t > 0)"
        projections.append(f"list(DISTINCT {field} ORDER BY {field}) FILTER (WHERE {condition}) AS {name}")
    row = run_sql(duckdb, f"SELECT {', '.join(projections)} FROM read_parquet({literal(source)});", True)[0]
    if any(not row[name] for name in fields):
        raise ValueError("The source has no usable load or speed thresholds")
    return row


def metadata(layers, selected, representation, url_prefix):
    layer = next(layer for layer in layers if layer["id"] == selected)
    shown = {"max_axle_load_t": "axle", "max_mass_per_m_t": "per_m", "load_speed_kmh": "speed"}[layer["value"]]
    controls = {
        "shown": {"label": "Value shown", "type": "select", "default": shown,
                  "options": [{"value": "axle", "label": "Axle load (t)"},
                              {"value": "per_m", "label": "Mass per metre (t/m)"},
                              {"value": "speed", "label": "Speed (km/h)"}],
                  "help": "Axle load and mass per metre are separate queries. Zero means not allowed by the recorded limits. "
                          "Unknown results are omitted. H3 shows the best reported track in each cell."},
        "criterion_load": {"label": "Criterion", "type": "select",
                           "default": "per_m" if layer["predicate"] == "max_mass_per_m_t" else "axle",
                           "options": [{"value": "axle", "label": "Axle load"},
                                       {"value": "per_m", "label": "Mass per metre"}],
                           "showIf": "values => values.shown === 'speed'"},
        "criterion_speed": {"label": "Criterion", "type": "select", "default": "speed",
                            "options": [{"value": "speed", "label": "Speed"}],
                            "showIf": "values => values.shown !== 'speed'"},
    }
    for choice, field, preferred, unit in (
        ("axle", "max_axle_load_t", 22.5, "t/axle"),
        ("per_m", "max_mass_per_m_t", 8, "t/m"),
        ("speed", "load_speed_kmh", 120, "km/h"),
    ):
        numbers = sorted({item["threshold"] for item in layers if item["predicate"] == field})
        default = layer["threshold"] if layer["predicate"] == field else preferred if preferred in numbers else numbers[-1]
        controls[choice] = {
            "label": "Criterion value", "type": "select", "default": format(default, ".12g"),
            "options": [{"value": format(number, ".12g"), "label": f"{number:.12g} {unit}"} for number in numbers],
            "showIf": "values => values.shown !== 'speed'" if choice == "speed" else
                      f"values => values.shown === 'speed' && values.criterion_load === '{choice}'",
        }
    controls["speed"]["help"] = "Select 0 km/h to include recorded zero-speed load limits. This does not establish a permitted running speed."
    controls.update({
        "format": {"label": "Map format", "type": "select", "default": representation,
                   "options": [{"value": "h3", "label": "H3 — section starts"},
                               {"value": "geojson", "label": "GeoJSON — endpoint geometry"}]},
        "layer": {"label": "Map file", "type": "text", "default": selected, "showIf": "() => false",
                  "encode": "(value, v) => v.shown === 'speed' ? "
                            "(v.criterion_load === 'axle' ? 'speed-for-axle-' + v.axle.replace('.', 'p') + 't' : "
                            "'speed-for-per-m-' + v.per_m.replace('.', 'p') + 'tpm') : "
                            "(v.shown === 'axle' ? 'max-axle-at-' : 'max-per-m-at-') + v.speed.replace('.', 'p') + 'kmh'"},
        "extension": {"label": "File type", "type": "text", "default": "csv" if representation == "h3" else "geojson",
                      "showIf": "() => false", "encode": "(value, values) => values.format === 'h3' ? 'csv' : 'geojson'"},
    })
    return {
        "t": "{controls.shown}{ for {controls.axle}}{ for {controls.per_m}}{ at {controls.speed}}",
        "c": "ERA,UIC", "cartogram": "none", "crosshair": False,
        "colourScale": "linear", "trimFactor": 0, "colourScheme": "interpolateViridis",
        "controls": controls,
        "onchange": {"url": f"{url_prefix.rstrip('/')}/{{controls.format}}/{{controls.layer}}.{{controls.extension}}",
                     "format": "auto"},
    }


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def export(duckdb, source, output, resolution, url_prefix):
    choices = thresholds(duckdb, source)
    layers = []
    for family, choice, predicate, value, unit, label in FAMILIES:
        for threshold in choices[choice]:
            number = format(threshold, ".12g")
            layers.append({"id": f"{family}-{number.replace('.', 'p')}{unit}",
                           "label": label.format(n=number), "threshold": threshold,
                           "predicate": predicate, "value": value})
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".track-loads-", dir=output.parent) as tmp:
        work = Path(tmp)
        (work / "h3").mkdir()
        (work / "geojson").mkdir()
        sql = ["INSTALL spatial; LOAD spatial; INSTALL h3 FROM community; LOAD h3;"]
        fields = ["sol", "track", "load_category", "start_lon", "start_lat", "end_lon", "end_lat"]
        for field in ("max_axle_load_t", "max_mass_per_m_t", "load_speed_kmh"):
            comparison = ">= 0" if field == "load_speed_kmh" else "> 0"
            fields.append(f"CASE WHEN isfinite({field}) AND {field} {comparison} THEN {field} END AS {field}")
        sql.append(f"CREATE TEMP TABLE capabilities AS SELECT DISTINCT {', '.join(fields)} FROM read_parquet({literal(source)});")
        start = "isfinite(start_lon) AND isfinite(start_lat) AND start_lon BETWEEN -180 AND 180 AND start_lat BETWEEN -90 AND 90"
        end = "isfinite(end_lon) AND isfinite(end_lat) AND end_lon BETWEEN -180 AND 180 AND end_lat BETWEEN -90 AND 90"
        sql.append(f"""
            CREATE TEMP TABLE locations AS
            SELECT DISTINCT sol, track, start_lon, start_lat, end_lon, end_lat,
                CASE WHEN {start} THEN h3_latlng_to_cell_string(start_lat, start_lon, {resolution}) END AS h3_index,
                CASE
                    WHEN ({start}) AND ({end}) AND (start_lon <> end_lon OR start_lat <> end_lat)
                        THEN ST_AsGeoJSON(ST_MakeLine(ST_Point(start_lon, start_lat), ST_Point(end_lon, end_lat)))
                    WHEN {start} THEN ST_AsGeoJSON(ST_Point(start_lon, start_lat))
                    WHEN {end} THEN ST_AsGeoJSON(ST_Point(end_lon, end_lat))
                END AS geometry
            FROM capabilities;
        """)
        for layer in layers:
            known = f"{layer['predicate']} IS NOT NULL AND {layer['value']} IS NOT NULL"
            candidate = f"CASE WHEN {known} AND {layer['predicate']} >= {layer['threshold']} THEN {layer['value']} END"
            sql.append(f"""
                CREATE OR REPLACE TEMP TABLE answers AS
                SELECT sol, track,
                    CASE WHEN max({candidate}) IS NOT NULL THEN max({candidate})
                         WHEN bool_or(NOT ({known})) THEN NULL ELSE 0 END::DOUBLE AS value,
                    coalesce(arg_max(load_category, {candidate} ORDER BY load_category), '') AS load_category
                FROM capabilities GROUP BY sol, track;
                COPY (
                    SELECT h3_index AS index, max(value) AS value,
                        count(DISTINCT (sol, track)) AS tracks,
                        arg_max(load_category, value ORDER BY load_category) AS load_category
                    FROM locations JOIN answers USING (sol, track)
                    WHERE value IS NOT NULL AND h3_index IS NOT NULL
                    GROUP BY h3_index ORDER BY h3_index
                ) TO {literal(work / 'h3' / (layer['id'] + '.csv'))} (FORMAT CSV, HEADER);
                COPY (
                    SELECT 'FeatureCollection' AS type,
                        coalesce(list({{'type': 'Feature', 'geometry': geometry,
                            'properties': {{'sol': sol, 'track': track, 'value': value, 'load_category': load_category}}}}
                            ORDER BY sol, track, start_lon, start_lat, end_lon, end_lat), []) AS features
                    FROM locations JOIN answers USING (sol, track)
                    WHERE value IS NOT NULL AND geometry IS NOT NULL
                ) TO {literal(work / 'geojson' / (layer['id'] + '.geojson'))} (FORMAT JSON);
            """)
        print(f"Generating {2 * len(layers)} maps at H3 resolution {resolution}...", flush=True)
        run_sql(duckdb, "\n".join(sql))
        for layer in layers:
            for representation in ("h3", "geojson"):
                write_json(work / representation / (layer["id"] + ".json"),
                           metadata(layers, layer["id"], representation, url_prefix))
        default = next((layer["id"] for layer in layers if layer["id"] == "speed-for-axle-22p5t"), layers[0]["id"])
        shutil.copyfile(work / "h3" / (default + ".csv"), work / "index.csv")
        write_json(work / "index.json", metadata(layers, default, "h3", url_prefix))
        write_json(work / "manifest.json", {
            "source": source.name, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "h3_resolution": resolution, "h3_aggregation": "maximum", "h3_locations": "section starts",
            "geojson_geometry": "straight endpoint lines; a single valid endpoint gives a point",
            "unknown_results": "omitted", "zero": "no recorded compatible class",
            "thresholds": choices, "data_files": 2 * len(layers), "layers": layers,
        })
        output.mkdir(parents=True, exist_ok=True)
        for path in sorted(work.rglob("*"), key=lambda path: path.suffix == ".json"):
            if path.is_file():
                target = output / path.relative_to(work)
                target.parent.mkdir(parents=True, exist_ok=True)
                path.replace(target)
    print(f"Saved {2 * len(layers)} maps, metadata, and index.csv to {output}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Export static track-load maps and H3-MON controls.")
    parser.add_argument("--input", type=Path, default=Path("loads.parquet"))
    parser.add_argument("--output-dir", type=Path, default=Path("out/track-loads"))
    parser.add_argument("--url-prefix", default="data/track-loads")
    parser.add_argument("--resolution", type=int, default=5)
    parser.add_argument("--duckdb", default=shutil.which("duckdb") or str(Path.home() / ".duckdb/cli/latest/duckdb"))
    args = parser.parse_args(argv)
    if not 0 <= args.resolution <= 15:
        parser.error("H3 resolution must be between 0 and 15")
    try:
        export(args.duckdb, args.input.resolve(), args.output_dir.resolve(), args.resolution, args.url_prefix)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Error: {getattr(error, 'stderr', None) or str(error)}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
