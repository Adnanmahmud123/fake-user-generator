"""Measure end-to-end stored-procedure throughput against the configured MySQL DB.

Run after installing the current procedures.sql and configuring .env.
Times include database round-trip, procedure execution, result transfer, fetch, and commit.
They are not a pure server-only CPU benchmark.
"""
import os
import statistics
import time
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env", override=False)


def connection_options():
    opts = {
        "host": os.getenv("DB_HOST", "127.0.0.1").strip(),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "root").strip(),
        "password": os.getenv("DB_PASSWORD", ""),
        "database": os.getenv("DB_NAME", "fake_user_generator").strip(),
        "charset": "utf8mb4",
        "connection_timeout": 20,
        "autocommit": False,
    }
    ca = os.getenv("DB_SSL_CA", "").strip()
    if ca:
        ca_path = Path(ca)
        if not ca_path.is_absolute():
            ca_path = BASE_DIR / ca_path
        if not ca_path.is_file():
            raise FileNotFoundError(f"DB_SSL_CA file not found: {ca_path}")
        opts.update(ssl_ca=str(ca_path), ssl_verify_cert=True, ssl_verify_identity=True)
    return opts


def run_once(locale: str, seed: int, batch_size: int):
    conn = mysql.connector.connect(**connection_options())
    try:
        cur = conn.cursor()
        started = time.perf_counter()
        cur.callproc("generate_user_batch", (locale, seed, 0, batch_size))
        rows = []
        for result in cur.stored_results():
            rows.extend(result.fetchall())
        conn.commit()
        elapsed = time.perf_counter() - started
        cur.close()
        if len(rows) != batch_size:
            raise RuntimeError(
                f"Expected {batch_size} rows but procedure returned {len(rows)}. "
                "Check the procedure and selected database."
            )
        return elapsed, len(rows)
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def main():
    locale = os.getenv("BENCHMARK_LOCALE", "en_US")
    base_seed = int(os.getenv("BENCHMARK_SEED", str(int(time.time()) % 2_000_000_000)))
    batch_sizes = [100, 500, 1000]
    trials = int(os.getenv("BENCHMARK_TRIALS", "3"))

    print(f"Database: {os.getenv('DB_HOST', '127.0.0.1')}:{os.getenv('DB_PORT', '3306')}/{os.getenv('DB_NAME', 'fake_user_generator')}")
    print(f"Locale: {locale}; trials per size: {trials}")
    print("Metric includes procedure call, result fetch, network round-trip, and commit.")
    print("Running 10-row warm-up...")
    run_once(locale, base_seed + 1, 10)

    print("\nBatch size | Median seconds | Users/second | Trial seconds")
    print("-----------|----------------|--------------|--------------")
    for size in batch_sizes:
        durations = []
        for trial in range(trials):
            # A different seed per trial measures fresh inserts rather than only upserts.
            seed = base_seed + size * 100 + trial + 1000
            elapsed, count = run_once(locale, seed, size)
            durations.append(elapsed)
        median_seconds = statistics.median(durations)
        rate = size / median_seconds if median_seconds else float("inf")
        trial_text = ", ".join(f"{x:.3f}" for x in durations)
        print(f"{size:10d} | {median_seconds:14.3f} | {rate:12.2f} | {trial_text}")

    print("\nCopy these measured values into the README / submission notes.")
    print("Do not compare results from different databases or network conditions as if identical.")


if __name__ == "__main__":
    main()
