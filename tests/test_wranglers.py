import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DUCKDB = os.environ.get("DUCKDB") or shutil.which("duckdb")
CRS84 = "<http://www.opengis.net/def/crs/OGC/1.3/CRS84> "


@unittest.skipUnless(DUCKDB, "Set DUCKDB or put the DuckDB CLI on PATH")
class WranglerTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.work = Path(tmp.name)

    def fixture(self, name, columns, rows):
        with (self.work / name).open("w", newline="") as target:
            writer = csv.writer(target)
            writer.writerow(columns)
            writer.writerows(rows)

    def run_script(self, name):
        subprocess.run([DUCKDB, "-bail", "-f", str(ROOT / name)], cwd=self.work,
                       check=True, capture_output=True, text=True, timeout=120)

    def query(self, sql):
        result = subprocess.run([DUCKDB, "-json", "-c", sql], cwd=self.work,
                                check=True, capture_output=True, text=True, timeout=30)
        return json.loads(result.stdout)

    def test_gauges_do_not_require_speed_or_platform_exports(self):
        self.fixture("out.csv", ["sol", "startWKT", "endWKT", "track", "gp", "gpLabel"], [
            ["section", "POINT (2 48)", CRS84 + "POINT (3 49)", "a", "http://example/gauge/20", "GB"],
            ["section", "POINT (2 48)", "POINT (3 49)", "b", "http://example/gauge/10", "GA"],
        ])
        self.run_script("wrangler.sql")
        rows = self.query("SELECT * FROM read_parquet('out.parquet');")
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]["start_lon"], rows[0]["end_lat"], rows[0]["gp"]), (2, 49, 10))
        self.assertTrue((self.work / "gauge_labels.csv").is_file())

    def test_gauge_geometry_tables_need_no_downloaded_data(self):
        self.run_script("gauge_geometries.sql")
        for name in ("gauge_areas", "train_to_possible_tracks", "track_to_possible_trains",
                     "track_to_biggest_international_train"):
            self.assertTrue((self.work / (name + ".csv")).is_file())
        rows = self.query("SELECT * FROM read_csv('gauge_areas.csv') WHERE gauge_name = 'GC';")
        self.assertGreater(rows[0]["area"], 0)
        polygons = self.query("SELECT count(*) AS n FROM read_json('polygons.json');")
        self.assertGreater(polygons[0]["n"], 5)

    def test_speed_export_is_independent_and_preserves_units(self):
        self.fixture("speeds.csv", ["startWKT", "endWKT", "speed"], [
            ["POINT (2 48)", "POINT (3 49)", 90],
            [CRS84 + "POINT (2 48)", "POINT (3 49)", 120],
        ])
        self.run_script("wrangler_speed.sql")
        rows = self.query("SELECT * FROM read_parquet('speeds.parquet');")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["speed"], 120)

    def test_uk_export_uses_supplied_tables_and_preserves_coordinates(self):
        network = self.work / "network-rail-gis/network-model/VectorLinks"
        network.mkdir(parents=True)
        (self.work / "nesa_wrangled").mkdir()
        self.fixture("elr_to_line_of_route.csv", ["Line of route", "ELR"], [["route", "AAA"]])
        self.fixture("nesa_wrangled/fixture.csv",
                     ["LINE OF ROUTE", "W6", "W6A", "W7", "W8", "W9", "W9PLUS", "W10", "W10A", "W12"],
                     [["route", "Y", "N", "N", "Y *", "N", "N", "N", "N", "N"]])
        subprocess.run([DUCKDB, "-bail", "-c", """
            LOAD spatial;
            COPY (SELECT 'AAA' AS ELR, ST_GeomFromText('LINESTRING (530000 180000, 530100 180100)') AS geom)
            TO 'network-rail-gis/network-model/VectorLinks/NetworkLinks.shp'
            (FORMAT GDAL, DRIVER 'ESRI Shapefile', SRS 'EPSG:27700');
        """], cwd=self.work, check=True, capture_output=True, text=True, timeout=30)
        self.run_script("uk/wrangler.sql")
        rows = self.query("SELECT * FROM read_parquet('uk.parquet');")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["gauge_label"], "W6A")
        self.assertAlmostEqual(rows[0]["latitude_start"], 51.5, delta=0.1)
        self.assertAlmostEqual(rows[0]["longitude_start"], -0.12, delta=0.1)

    def test_platform_maps_have_numeric_values_and_independent_measures(self):
        self.fixture("platforms.csv", ["length", "height", "WKT"], [
            [100, "550-760", "POINT (2 48)"],
            [250, None, CRS84 + "POINT (2 48)"],
            [90, "550", "POINT (2 48)"],
        ])
        (self.work / "out/platforms").mkdir(parents=True)
        self.run_script("wrangler_platforms.sql")
        for measure, expected, resolutions in (("heights", 760, (5, 9)), ("lengths", 250, (3, 5, 9))):
            for resolution in resolutions:
                rows = self.query(f"SELECT * FROM read_csv('out/platforms/{measure}-h3-{resolution}.csv');")
                self.assertEqual(len(rows), 1)
                self.assertEqual(rows[0]["value"], expected)
                self.assertTrue(rows[0]["index"].startswith(f"8{resolution:x}"))


if __name__ == "__main__":
    unittest.main()
