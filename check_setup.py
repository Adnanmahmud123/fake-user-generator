"""Check MySQL connection, routine installation, and deterministic batches.

Run from the project folder with: python check_setup.py
This creates/updates small test batches in generated_users.
"""
from app import get_db_connection

PROFILE_FIELDS = (
    "locale_code", "seed_value", "batch_index", "user_index", "first_name",
    "last_name", "full_name", "title", "street_address", "city",
    "region_name", "postal_code", "latitude", "longitude", "birth_date",
    "height_cm", "weight_kg", "eye_color", "phone", "email",
)


def fetch_batch(cursor, locale, seed, batch_index, batch_size):
    cursor.callproc("generate_user_batch", (locale, seed, batch_index, batch_size))
    rows = []
    for result in cursor.stored_results():
        rows.extend(result.fetchall())
    return rows


def main():
    connection = None
    cursor = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("SELECT DATABASE() AS schema_name, VERSION() AS mysql_version")
        info = cursor.fetchone()
        print(f"[OK] Connected to MySQL {info['mysql_version']}")
        print(f"[INFO] Selected schema: {info['schema_name']}")

        cursor.execute(
            """SELECT ROUTINE_NAME, ROUTINE_TYPE
               FROM information_schema.ROUTINES
               WHERE ROUTINE_SCHEMA = DATABASE()
                 AND ROUTINE_NAME IN ('generate_user_batch', 'generator_offset', 'generator_uniform')"""
        )
        routines = {(r["ROUTINE_NAME"], r["ROUTINE_TYPE"]) for r in cursor.fetchall()}
        required_routines = {
            ("generate_user_batch", "PROCEDURE"),
            ("generator_offset", "FUNCTION"),
            ("generator_uniform", "FUNCTION"),
        }
        missing_routines = required_routines - routines
        if missing_routines:
            raise RuntimeError(f"Missing routine(s): {sorted(missing_routines)}")
        print("[OK] Main procedure and both deterministic helper functions exist")

        required_tables = [
            "locales", "names", "titles", "street_names", "cities",
            "eye_colors", "email_domains", "generated_users",
        ]
        cursor.execute(
            "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()"
        )
        existing = {row["TABLE_NAME"] for row in cursor.fetchall()}
        missing = [name for name in required_tables if name not in existing]
        if missing:
            raise RuntimeError("Missing required table(s): " + ", ".join(missing))
        print("[OK] All required tables exist")

        cursor.execute("SELECT locale_code, COUNT(*) AS n FROM names GROUP BY locale_code")
        counts = {row["locale_code"]: row["n"] for row in cursor.fetchall()}
        for locale in ("en_US", "de_DE"):
            print(f"[INFO] {locale}: {counts.get(locale, 0)} name combinations")
            if counts.get(locale, 0) < 100:
                print(f"[WARN] {locale} has fewer than 100 name combinations; run expand_lookup_data.sql")

        for locale in ("en_US", "de_DE"):
            first = fetch_batch(cursor, locale, 987654321, 0, 5)
            second = fetch_batch(cursor, locale, 987654321, 0, 5)
            if len(first) != 5 or len(second) != 5:
                raise RuntimeError(f"{locale}: expected 5 rows per run; got {len(first)} and {len(second)}")
            if any(not row.get("full_name") or not row.get("email") or not row.get("phone") for row in first):
                raise RuntimeError(f"{locale}: missing required profile values")
            for row in first:
                lat = float(row["latitude"])
                lon = float(row["longitude"])
                if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                    raise RuntimeError(f"{locale}: invalid coordinates ({lat}, {lon})")
            for a, b in zip(first, second):
                if any(a[field] != b[field] for field in PROFILE_FIELDS):
                    raise RuntimeError(f"{locale}: repeatability check failed at user_index {a['user_index']}")
            print(f"[OK] {locale}: 5 users, valid coordinates, repeatability passed")

        connection.commit()
        print("\nALL CHECKS PASSED")
    except Exception as exc:
        if connection is not None:
            connection.rollback()
        print(f"\nCHECK FAILED: {exc}")
        raise SystemExit(1)
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()


if __name__ == "__main__":
    main()
