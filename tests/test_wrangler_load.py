import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from dump_loads import COLUMNS

ROOT = Path(__file__).resolve().parents[1]
DUCKDB = os.environ.get("DUCKDB") or shutil.which("duckdb")
LIMITS = {
    "A": (16.0, 5.0), "B1": (18.0, 5.0), "B2": (18.0, 6.4),
    "C2": (20.0, 6.4), "C3": (20.0, 7.2), "C4": (20.0, 8.0),
    "D2": (22.5, 6.4), "D3": (22.5, 7.2), "D4": (22.5, 8.0),
    "E4": (25.0, 8.0), "E5": (25.0, 8.8),
}


def record(section, category="", speed="90", label="", geometry="POINT(3 4)"):
    return [section, "POINT(1 2)", geometry, "track", "source",
            f"{category}/{speed}", "category", category, label, speed]


@unittest.skipUnless(DUCKDB, "Set DUCKDB or put the DuckDB CLI on PATH")
class WranglerLoadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.work = Path(tmp.name)
        geometry = "LINESTRING (" + ", ".join(["3 4"] * 40000) + ")"
        rows = [record("baseline", "D4")] * 21000
        rows += [record(category, category) for category in LIMITS]
        rows += [record(category, category, "80") for category in ("RA1", "RA10", "RA11", "HS17", "D4xL", "Z9")]
        rows += [record("missing", speed=""), record("label_only", label="B2"),
                 record("invalid_speed", "D4", "invalid"),
                 record("paired", "C4", "120"), record("paired", "D4", "90"),
                 record("quoted", "C4", label='A comma, a "quote" and\na newline', geometry=geometry)]
        cls.row_count = len(rows)
        with (cls.work / "loads.csv").open("w", encoding="utf-8", newline="") as target:
            writer = csv.writer(target)
            writer.writerow(COLUMNS)
            writer.writerows(rows)
        subprocess.run([DUCKDB, "-bail", "-f", str(ROOT / "wrangler_load.sql")],
                       cwd=cls.work, check=True, capture_output=True, text=True)

    def query(self, sql):
        result = subprocess.run([DUCKDB, "-bail", "-json", "-c", sql],
                                cwd=self.work, check=True, capture_output=True, text=True)
        return json.loads(result.stdout)

    def test_all_standard_limits(self):
        rows = self.query("SELECT * FROM read_parquet('loads.parquet') WHERE sol = load_category")
        actual = {row["sol"]: row for row in rows}
        for category, (axle, per_m) in LIMITS.items():
            with self.subTest(category=category):
                self.assertEqual(actual[category]["max_axle_load_t"], axle)
                self.assertEqual(actual[category]["max_mass_per_m_t"], per_m)
                self.assertEqual(actual[category]["load_speed_unit"], "km/h")
                self.assertEqual(actual[category]["load_speed_kmh"], 90.0)

    def test_special_and_unknown_limits_are_null(self):
        rows = self.query("""
            SELECT * FROM read_parquet('loads.parquet')
            WHERE sol IN ('RA1', 'RA10', 'RA11', 'HS17', 'D4xL', 'Z9', 'missing')
        """)
        self.assertEqual(len(rows), 7)
        for row in rows:
            with self.subTest(category=row["sol"]):
                self.assertIsNone(row["max_axle_load_t"])
                self.assertIsNone(row["max_mass_per_m_t"])
                if row["sol"] in ("RA1", "RA10"):
                    self.assertEqual(row["load_speed_unit"], "mph")
                    self.assertAlmostEqual(row["load_speed_kmh"], 128.74752)
                elif row["sol"] in ("HS17", "D4xL"):
                    self.assertEqual(row["load_speed_unit"], "km/h")
                    self.assertEqual(row["load_speed_kmh"], 80.0)
                else:
                    self.assertIsNone(row["load_speed_unit"])
                    self.assertIsNone(row["load_speed_kmh"])

    def test_label_fallback_and_invalid_speed(self):
        row = self.query("SELECT * FROM read_parquet('loads.parquet') WHERE sol = 'label_only'")[0]
        self.assertEqual(row["load_category"], "B2")
        self.assertEqual((row["max_axle_load_t"], row["max_mass_per_m_t"]), LIMITS["B2"])
        row = self.query("SELECT * FROM read_parquet('loads.parquet') WHERE sol = 'invalid_speed'")[0]
        self.assertIsNone(row["load_speed"])
        self.assertIsNone(row["load_speed_kmh"])
        self.assertEqual(row["max_axle_load_t"], 22.5)

    def test_class_speed_pairs_stay_separate(self):
        rows = self.query("""
            SELECT load_category, max_axle_load_t, max_mass_per_m_t, load_speed_kmh
            FROM read_parquet('loads.parquet') WHERE sol = 'paired'
        """)
        self.assertEqual({tuple(row.values()) for row in rows},
                         {("C4", 20.0, 8.0, 120.0), ("D4", 22.5, 8.0, 90.0)})

    def test_all_raw_fields_survive_late_quoted_records(self):
        count = self.query("SELECT count(*) AS n FROM read_parquet('loads.parquet')")[0]["n"]
        self.assertEqual(count, self.row_count)
        changed = self.query(f"""
            SELECT count(*) AS n FROM (
                SELECT * FROM read_csv('loads.csv', header = true, all_varchar = true,
                                       delim = ',', quote = '"', escape = '"')
                EXCEPT ALL
                SELECT {', '.join(COLUMNS)} FROM read_parquet('loads.parquet')
            )
        """)[0]["n"]
        self.assertEqual(changed, 0)


if __name__ == "__main__":
    unittest.main()
