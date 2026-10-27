# Fake User Generator

A Flask web application that displays fictional user profiles generated and persisted by MySQL stored SQL logic. Python only validates the form, calls `generate_user_batch`, and renders the result; profile values are generated in MySQL.

## Requirements

- MySQL 8.x / Aiven MySQL with stored routine privileges
- Python 3.10+
- Dependencies in `requirements.txt`
- An existing `.env` file (copy `.env.example` and enter credentials privately)

## Files

- `app.py` — Flask UI and stored procedure caller
- `templates/index.html` — locale/seed/batch controls and results table
- `schema.sql` — initial database/table definitions and small starter lookup set (for a new database only)
- `expand_lookup_data.sql` — adds hundreds of name combinations per locale and more street names; safe to rerun
- `procedures.sql` — `generator_offset` SQL helper function and `generate_user_batch` stored procedure
- `benchmark.py` — measures actual throughput against the configured database
- `check_setup.py` — checks connection, procedure, lookup tables, and small batches
- `.env.example` — environment-variable template, no real credentials

## Installation / update order

### New database

1. Run `schema.sql` once in a local MySQL instance (it creates `fake_user_generator`).
2. In `expand_lookup_data.sql` and `procedures.sql`, change the first `USE defaultdb;` to `USE fake_user_generator;` before running against that local schema.
3. Run `expand_lookup_data.sql`.
4. Run `procedures.sql`.
5. Configure `.env` and start the Flask app.

### Existing Aiven database

Do **not** rerun `schema.sql` on a populated Aiven database; it is an initial schema/seed script and its starter inserts are not intended as a repeated migration. The provided scripts target `defaultdb`, matching the Aiven configuration used for this project. If your tables are in a different schema, change the first `USE ...;` line in both SQL files before running them.

1. Back up the current schema/data or export the database before changes.
2. Run `expand_lookup_data.sql` in the schema that contains `names` and `street_names`.
3. Run `procedures.sql` in that same schema. It replaces `generator_offset`, `generator_uniform`, and `generate_user_batch`; it does not drop generated user rows or lookup tables.
4. Run `python check_setup.py` and then use the UI.

Set one copy of each variable in `.env`:

```dotenv
DB_HOST=your-aiven-host
DB_PORT=your-aiven-port
DB_NAME=defaultdb
DB_USER=avnadmin
DB_PASSWORD=your-real-password
DB_SSL_CA=ca.pem
FLASK_DEBUG=false
```

Use the exact database/schema name where your tables and routine live. Do not share `.env`, passwords, or private certificates publicly.

## Use

Run in VS Code PowerShell from the project folder:

```powershell
python -m pip install -r requirements.txt
python app.py
```

Open `http://127.0.0.1:5000`. Select `en_US` or `de_DE`, enter a non-negative seed, choose a batch index and batch size (1–1000), and generate. **Next Batch** increments the batch index while retaining the other form inputs.

Stored procedure example:

```sql
CALL generate_user_batch('en_US', 654321, 0, 10);
CALL generate_user_batch('en_US', 654321, 1, 10);
```

For reproducibility, keep locale, seed, batch index, and batch size unchanged when repeating the same request. The absolute `user_index` is `batch_index * batch_size + position_in_batch`.

## Stored SQL routines and algorithms

### `generator_uniform(p_locale, p_seed, p_user_index, p_field) RETURNS DOUBLE`

A deterministic helper that hashes locale, seed, user index, and field label with SHA-256. The first 32 hash bits are converted to a value strictly between zero and one. Distinct field labels create separate deterministic pseudo-uniform inputs.

### `generator_offset(p_locale, p_seed, p_user_index, p_field, p_count) RETURNS INT`

A deterministic selection helper. It hashes locale, seed, user index, and field label with `CRC32`, then applies modulo `p_count`. A different field label separates choices for title/street/eye/domain/phone/address fields. Returns zero when `p_count` is null or less than one.

### `generate_user_batch(p_locale, p_seed, p_batch_index, p_batch_size)`

- `p_locale`: locale key present in `locales`, currently `en_US` and `de_DE`.
- `p_seed`: non-null seed value.
- `p_batch_index`: zero-based, non-negative batch index.
- `p_batch_size`: 1–1000.

The procedure validates inputs and required locale lookup data, selects locale-aware names, compatible titles (including a deterministic no-title variation), street/city/region/postal data, eye color and email domain. It creates a stable synthetic phone number with one of three locale-specific formats. Email includes the seed and user index so generated email strings are distinct for different user positions in the same locale/seed run.

**Coordinates:** Two independent deterministic pseudo-uniform values are derived from SHA-256 hashes. Longitude is `360*v - 180`. Latitude is `DEGREES(ASIN(2*u - 1))`. Uniform latitude itself is incorrect for a uniform point on a sphere; `sin(latitude)` must be uniform, which this inverse-transform formula achieves. Coordinates are global and are intentionally not claimed to match the selected city.

**Height and weight:** The procedure uses the Box–Muller transform `z = sqrt(-2 ln(u1)) * cos(2*pi*u2)` with deterministic SHA-256-derived pseudo-uniform inputs. Height is centered at 170 cm with scale 10 cm; weight at 75 kg with scale 15 kg. Values are clamped to plausible bounds (height 145–200 cm; weight 40–160 kg), so these are truncated normal-like distributions, not unbounded exact normal distributions.

**Persistence:** Generated profiles are upserted under the composite unique key `(locale_code, seed_value, batch_index, user_index)`. If the same batch is later requested with a smaller size, stale rows outside the new range for that same locale/seed/batch are removed. Other runs and batches are preserved.

## Lookup data and scale

`expand_lookup_data.sql` builds first-name/last-name combinations in the shared `names` table (locale is a column, not separate locale tables), producing roughly 900 combinations per locale, then adds street-name variety. The output table can store far more than one million rows, but throughput and disk usage depend on the database plan/tier. A million-row benchmark should only be attempted after a smaller benchmark succeeds and database capacity is understood.

## Tests

Run:

```powershell
python check_setup.py
```

The script checks the configured schema, required tables/routine, and a small test batch for each locale. It writes test rows. For a deterministic repeatability check, call the same locale/seed/batch index/size twice and compare all returned profile fields; ignore the auto-increment `id` and `created_at` metadata.

Useful SQL checks after generating a few thousand records:

```sql
SELECT locale_code, COUNT(*) AS rows_count,
       MIN(latitude) AS min_lat, MAX(latitude) AS max_lat,
       MIN(longitude) AS min_lon, MAX(longitude) AS max_lon,
       AVG(SIN(RADIANS(latitude))) AS mean_sin_lat,
       AVG(longitude) AS mean_lon
FROM generated_users
GROUP BY locale_code;

SELECT locale_code, COUNT(*) AS rows_count,
       COUNT(DISTINCT email) AS distinct_emails,
       SUM(first_name IS NULL OR last_name IS NULL OR email IS NULL
           OR phone IS NULL OR latitude IS NULL OR longitude IS NULL) AS incomplete_rows
FROM generated_users
GROUP BY locale_code;
```

For a large enough sample, coordinate ranges should remain within latitude [-90,90] and longitude [-180,180], and `mean_sin_lat` and `mean_lon` should be near zero. These are sanity checks, not a proof of uniformity.

## Real performance benchmark

Run the benchmark on the machine/network you plan to report from:

```powershell
python benchmark.py
```

It performs a 10-user warm-up, then tests batch sizes 100, 500, and 1000 with three different seeds per size and reports median elapsed seconds and users/second. The measurement includes the database round-trip, stored procedure execution, row transfer/fetch, and commit. It is an end-to-end throughput measure, not a pure database-engine-only benchmark. The script uses the credentials in `.env` and inserts test profiles; use a test schema if you do not want benchmark rows in the main dataset.

Do not claim a benchmark number until this script has run against the configured database. Save the terminal output in your submission notes and document the database tier/network used.

## Limitations

- Names and addresses are synthetic; phone numbers/emails are not guaranteed to be deliverable or belong to real users.
- The current city list is small compared with the expanded name table. Add more locale-specific cities and street names for greater address diversity.
- CRC32 is deterministic and fast but is not a cryptographic random generator; this application is for synthetic test data, not security-sensitive tokens.
- The output is reproducible for the same locale, seed, batch index, batch size, lookup-table contents/order, and procedure version. Changing lookup rows or their IDs can change generated profiles.
## Performance Benchmark

**Database:** Aiven MySQL 8.4.11  
**Locale:** `en_US`  
**Trials per batch size:** 3

The benchmark measures the complete operation, including the stored procedure call, result fetching, network round-trip, and commit. A 10-row warm-up was performed before the measurements.

| Batch size | Median time (seconds) | Throughput (users/second) | Trial times (seconds) |
|---:|---:|---:|---|
| 100 | 1.126 | 88.80 | 1.279, 1.060, 1.126 |
| 500 | 4.029 | 124.11 | 4.029, 4.726, 3.961 |
| 1,000 | 7.524 | 132.91 | 7.524, 10.001, 7.368 |

### Observations

- The highest measured throughput was **132.91 users/second** at a batch size of 1,000.
- Throughput increased with batch size in these tests, while total execution time also increased.
- These results represent the tested Aiven MySQL database and network conditions. Results may differ under other conditions.
- These measurements do not, by themselves, establish performance at 100,000–1,000,000 users. Larger-scale testing is still required.

### Reproducibility

The benchmark was run using the project's `benchmark.py` script. The Python connector displayed a deprecation warning for `stored_results()`; the benchmark completed and produced the measurements shown above.