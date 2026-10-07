#!/usr/bin/env python3
import argparse
from contextlib import contextmanager
import csv
import fcntl
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
COLUMNS = ["sol", "startWKT", "endWKT", "track", "loadSource", "loadCapability",
           "loadCategory", "loadCategoryCode", "loadCategoryLabel", "loadSpeed"]
ENDPOINT = "https://rinf.data.era.europa.eu/api/sparql"


@contextmanager
def atomic_text(path):
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="",
                                     dir=path.parent, suffix=".csv", delete=False) as output:
        temporary = Path(output.name)
        try:
            yield output
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def read_csv(path, columns):
    with path.open(encoding="utf-8-sig", newline="") as source:
        reader = csv.reader(source)
        if next(reader, None) != columns:
            raise ValueError(f"Unexpected CSV header in {path}")
        rows = list(reader)
    if any(len(row) != len(columns) for row in rows):
        raise ValueError(f"Incomplete CSV record in {path}")
    return rows


def write_csv(path, columns, rows):
    with atomic_text(path) as output:
        writer = csv.writer(output)
        writer.writerow(columns)
        writer.writerows(rows)


def query_csv(query, columns, args):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "response.csv"
        subprocess.run([
            "curl", "--fail", "--silent", "--show-error", "--location", "--compressed",
            "--retry", str(args.retries), "--retry-delay", "1",
            "--connect-timeout", str(min(15, args.timeout)), "--max-time", str(args.timeout),
            "--retry-max-time", str((args.timeout + 5) * (args.retries + 1)),
            "-H", "Accept: text/csv", "-H", "Content-Type: application/sparql-query",
            "--data-binary", "@-", "--output", str(path), "--url", args.endpoint,
        ], input=query, text=True, encoding="utf-8", check=True,
           timeout=(args.timeout + 5) * (args.retries + 1))
        return read_csv(path, columns)


def batch_query(query, sections):
    if any(not re.fullmatch(r'https?://[^\s<>"{}|^`\\]+', uri) for uri in sections):
        raise ValueError("The section list contains an invalid URI")
    if "WHERE {\n" not in query:
        raise ValueError("The load query has no batch insertion point")
    values = " ".join(f"<{uri}>" for uri in sections)
    return query.replace("WHERE {\n", f"WHERE {{\n    VALUES ?sol {{ {values} }}\n", 1)


def inventory(cache, query, args):
    path, count_path = cache / "sections.csv", cache / "sections-count.csv"
    cached = path.exists() and count_path.exists()
    rows = read_csv(path, ["sol"]) if cached else query_csv(query, ["sol"], args)
    count_query = query.replace("SELECT DISTINCT ?sol", "SELECT (COUNT(DISTINCT ?sol) AS ?count)", 1)
    counts = read_csv(count_path, ["count"]) if cached else query_csv(count_query, ["count"], args)
    sections = sorted(row[0] for row in rows)
    if len(counts) != 1 or int(counts[0][0]) != len(sections) or len(set(sections)) != len(sections):
        raise ValueError("Section inventory is incomplete or changed during download; run again")
    if not sections:
        raise ValueError("ERA returned no sections; no export was written")
    batch_query("WHERE {\n}", sections)
    if not cached:
        write_csv(count_path, ["count"], counts)
        write_csv(path, ["sol"], [[uri] for uri in sections])
    return sections


def export(args, output, cache):
    query = (ROOT / "query_load.sparql").read_text()
    sections_query = (ROOT / "query_load_sections.sparql").read_text()
    settings = {
        "endpoint": args.endpoint, "batch_size": args.batch_size,
        "query_sha256": hashlib.sha256(query.encode()).hexdigest(),
        "inventory_sha256": hashlib.sha256(sections_query.encode()).hexdigest(),
    }
    manifest = cache / "settings.json"
    if manifest.exists():
        if json.loads(manifest.read_text()) != settings:
            raise ValueError("Cache settings differ. Use --cache-dir with a new directory")
    else:
        if list(cache.glob("*.csv")):
            raise ValueError("Cache metadata is missing. Use --cache-dir with a new directory")
        with atomic_text(manifest) as target:
            json.dump(settings, target, indent=2)

    sections = inventory(cache, sections_query, args)
    total = (len(sections) + args.batch_size - 1) // args.batch_size
    print(f"{len(sections):,} sections; {total} batches. Cache: {cache}", flush=True)
    with tempfile.TemporaryDirectory(prefix=".load-export-", dir=output) as tmp:
        work = Path(tmp)
        count = 0
        with (work / "loads.csv").open("w", encoding="utf-8", newline="") as target:
            writer = csv.writer(target)
            writer.writerow(COLUMNS)
            for number, start in enumerate(range(0, len(sections), args.batch_size), 1):
                batch = sections[start:start + args.batch_size]
                path = cache / f"batch-{number:06d}.csv"
                cached = path.exists()
                rows = read_csv(path, COLUMNS) if cached else query_csv(batch_query(query, batch), COLUMNS, args)
                batch_set = set(batch)
                if any(row[0] not in batch_set for row in rows):
                    raise ValueError(f"Batch {number} contains a section outside the requested batch")
                if not cached:
                    write_csv(path, COLUMNS, rows)
                writer.writerows(rows)
                count += len(rows)
                print(f"Batch {number}/{total}: {len(rows):,} rows ({'cached' if cached else 'downloaded'})", flush=True)

        duckdb = shutil.which("duckdb") if not args.csv_only else None
        if duckdb:
            subprocess.run([duckdb, "-bail"], input=(ROOT / "wrangler_load.sql").read_text(),
                           text=True, cwd=work, check=True)
        (work / "loads.csv").replace(output / "loads.csv")
        print(f"Saved {output / 'loads.csv'}: {count:,} rows", flush=True)
        if duckdb:
            (work / "loads.parquet").replace(output / "loads.parquet")
            print(f"Saved {output / 'loads.parquet'}", flush=True)
        else:
            print("Parquet was not built; any existing loads.parquet is unchanged.", flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Download ERA track loads in cached VALUES batches. Requires Python 3 and curl.")
    parser.add_argument("--output-dir", type=Path, default=Path.cwd())
    parser.add_argument("--cache-dir", type=Path, help="Default: OUTPUT_DIR/.load-cache. Use a new directory for a fresh export.")
    parser.add_argument("--batch-size", type=int, default=500)
    parser.add_argument("--timeout", type=int, default=60, help="Seconds per HTTP attempt (default: 60)")
    parser.add_argument("--retries", type=int, default=3, help="Retries for transient HTTP errors (default: 3)")
    parser.add_argument("--endpoint", default=ENDPOINT)
    parser.add_argument("--csv-only", action="store_true", help="Do not run DuckDB")
    args = parser.parse_args(argv)
    if args.batch_size < 1 or args.timeout < 1 or args.retries < 0:
        parser.error("Batch size and timeout must be positive; retries must be non-negative")
    try:
        if not shutil.which("curl"):
            raise ValueError("curl is not installed")
        output = args.output_dir.resolve()
        cache = (args.cache_dir or output / ".load-cache").resolve()
        output.mkdir(parents=True, exist_ok=True)
        cache.mkdir(parents=True, exist_ok=True)
        with (cache / ".lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise ValueError("Another downloader is using this cache") from None
            export(args, output, cache)
    except KeyboardInterrupt:
        print("\nStopped. Run the same command to resume.", file=sys.stderr)
        return 130
    except (OSError, ValueError, csv.Error, subprocess.SubprocessError) as error:
        print(f"Error: {error}\nCompleted batches remain cached. Run again to resume.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
