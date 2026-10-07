import csv
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import export_load_maps

DUCKDB = os.environ.get("DUCKDB") or shutil.which("duckdb")


def record(section, axle, per_m, speed, category="C4", lat=51.5, lon=-0.1):
    return {"sol": section, "track": "track", "load_category": category,
            "max_axle_load_t": axle, "max_mass_per_m_t": per_m, "load_speed_kmh": speed,
            "start_lat": lat, "start_lon": lon, "end_lat": lat + 0.1, "end_lon": lon + 0.1}


@unittest.skipUnless(DUCKDB, "Set DUCKDB or put the DuckDB CLI on PATH")
class ExportLoadMapsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        work = Path(tmp.name)
        cls.output = work / "maps"
        records = [record("paired", 20, 8, 120), record("paired", 22.5, 8, 90, "D4"),
                   record("same_cell", 20, 8, 120, lat=51.501),
                   record("zero", 20, 8, 120, lat=48.85, lon=2.35),
                   record("unknown", None, None, 90, "RA1", lat=52.5, lon=13.4),
                   record("mixed", 20, 8, 120, lat=50, lon=8),
                   record("mixed", None, None, 120, "RA1", lat=50, lon=8),
                   record("partial", 22.5, 8, 90, "D4", lat=53.35, lon=-6.26),
                   record("partial", None, None, 120, "RA1", lat=53.35, lon=-6.26),
                   record("cross", 22.5, 6.4, 120, "D2", lat=45, lon=11.5),
                   record("cross", 20, 8, 90, lat=45, lon=11.5),
                   record("invalid_speed", 20, 8, None, lat=47, lon=12),
                   record("no_speed", 22.5, 8, 0, "D4", lat=46.32, lon=-0.96)]
        end_only = record("end_only", 22.5, 8, 90, "D4")
        end_only.update(start_lat=None, start_lon=None)
        records.append(end_only)
        fixture = work / "source.json"
        fixture.write_text(json.dumps(records), encoding="utf-8")
        source = work / "loads.parquet"
        export_load_maps.run_sql(DUCKDB, f"COPY (FROM read_json_auto({export_load_maps.literal(fixture)})) "
                                f"TO {export_load_maps.literal(source)} (FORMAT PARQUET);")
        with redirect_stdout(io.StringIO()):
            export_load_maps.export(DUCKDB, source, cls.output, 5, "data/track-loads")

    def features(self, name):
        data = json.loads((self.output / "geojson" / (name + ".geojson")).read_text())
        self.assertEqual(data["type"], "FeatureCollection")
        return {feature["properties"]["sol"]: feature for feature in data["features"]}

    def test_separate_queries_preserve_speed_pairs(self):
        axle = self.features("speed-for-axle-22p5t")
        self.assertEqual(axle["paired"]["properties"]["value"], 90)
        self.assertEqual(axle["cross"]["properties"]["value"], 120)
        self.assertEqual(self.features("speed-for-per-m-8tpm")["cross"]["properties"]["value"], 90)
        self.assertEqual(self.features("max-axle-at-120kmh")["paired"]["properties"]["value"], 20)
        self.assertEqual(self.features("max-per-m-at-120kmh")["cross"]["properties"]["value"], 6.4)

    def test_known_failure_is_zero_and_unknown_is_omitted(self):
        features = self.features("speed-for-axle-22p5t")
        self.assertEqual(features["zero"]["properties"]["value"], 0)
        self.assertEqual(features["partial"]["properties"]["value"], 90)
        for section in ("unknown", "mixed", "invalid_speed"):
            self.assertNotIn(section, features)
        self.assertEqual(features["paired"]["geometry"]["type"], "LineString")
        self.assertEqual(features["end_only"]["geometry"]["type"], "Point")

    def test_zero_speed_reveals_load_limits_without_assuming_running_speed(self):
        for family, expected in (("max-axle-at", 22.5), ("max-per-m-at", 8)):
            features = self.features(f"{family}-0kmh")
            self.assertEqual(features["no_speed"]["properties"]["value"], expected)
            self.assertNotIn("invalid_speed", features)
            self.assertNotIn("unknown", features)
            self.assertEqual(self.features(f"{family}-90kmh")["no_speed"]["properties"]["value"], 0)
        self.assertEqual(self.features("speed-for-axle-22p5t")["no_speed"]["properties"]["value"], 0)

    def test_h3_uses_starts_and_maximum_after_track_query(self):
        with (self.output / "h3/speed-for-axle-22p5t.csv").open(newline="") as source:
            rows = list(csv.DictReader(source))
        self.assertEqual(len(rows), len({row["index"] for row in rows}))
        index = export_load_maps.run_sql(DUCKDB, "LOAD h3; SELECT h3_latlng_to_cell_string(51.5, -0.1, 5) AS index;", True)[0]["index"]
        row = next(row for row in rows if row["index"] == index)
        self.assertEqual(float(row["value"]), 90)
        self.assertEqual(int(row["tracks"]), 2)
        self.assertTrue(all(row["value"] and float(row["value"]) >= 0 for row in rows))

    def test_file_count_and_all_metadata_options(self):
        manifest = json.loads((self.output / "manifest.json").read_text())
        self.assertEqual(manifest["data_files"], 2 * (2 + 2 + 2 * 3))
        self.assertEqual(manifest["thresholds"]["speed"], [0, 90, 120])
        self.assertEqual(manifest["unknown_results"], "omitted")
        for layer in manifest["layers"]:
            for representation, extension in (("h3", "csv"), ("geojson", "geojson")):
                path = self.output / representation / (layer["id"] + "." + extension)
                self.assertTrue(path.is_file())
                meta = json.loads(path.with_suffix(".json").read_text())
                self.assertEqual(meta["controls"]["format"]["default"], representation)
                self.assertEqual(meta["controls"]["layer"]["default"], layer["id"])
                self.assertEqual(meta["controls"]["layer"]["showIf"], "() => false")
                shown = {"max_axle_load_t": "axle", "max_mass_per_m_t": "per_m", "load_speed_kmh": "speed"}
                criterion = shown[layer["predicate"]]
                self.assertEqual(meta["controls"]["shown"]["default"], shown[layer["value"]])
                self.assertEqual(meta["controls"][criterion]["default"], format(layer["threshold"], ".12g"))
                self.assertEqual(len(meta["controls"][criterion]["options"]), 3 if criterion == "speed" else 2)
                self.assertNotIn("showIf", meta["controls"]["format"])
                self.assertNotIn("colourScheme", meta)
                self.assertTrue(all("help" not in control for control in meta["controls"].values()))
                self.assertEqual([option["label"] for option in meta["controls"]["format"]["options"]],
                                 ["H3 hexagon cells", "Lines"])
                self.assertEqual(meta["onchange"]["format"], "auto")
                self.assertNotIn("onclick", meta)
                self.assertNotIn("onmove", meta)
        self.assertTrue((self.output / "index.csv").is_file())
        self.assertTrue((self.output / "index.json").is_file())

    @unittest.skipUnless(shutil.which("node"), "Put Node.js on PATH to check control expressions")
    def test_visible_controls_and_all_file_routes(self):
        manifest = json.loads((self.output / "manifest.json").read_text())
        maps = [{"id": layer["id"], "format": representation,
                 "metadata": json.loads((self.output / representation / (layer["id"] + ".json")).read_text())}
                for layer in manifest["layers"] for representation in ("h3", "geojson")]
        index = json.loads((self.output / "index.json").read_text())
        maps.append({"id": index["controls"]["layer"]["default"], "format": "h3", "metadata": index})
        subprocess.run(["node", str(Path(__file__).with_name("check_load_controls.mjs"))],
                       input=json.dumps({"layers": manifest["layers"], "maps": maps}),
                       text=True, check=True, capture_output=True)


if __name__ == "__main__":
    unittest.main()
