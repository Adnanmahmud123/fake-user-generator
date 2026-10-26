"""Verify the configured MySQL schema and the user-generation procedure.

Run from the project folder with:
    python check_setup.py

This script creates a small test batch through the stored procedure.
"""
from app import get_db_connection


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
            """
            SELECT COUNT(*) AS n
            FROM information_schema.ROUTINES
            WHERE ROUTINE_SCHEMA = DATABASE()
              AND ROUTINE_NAME = 'generate_user_batch'
              AND ROUTINE_TYPE = 'PROCEDURE'
            """
        )
        if cursor.fetchone()["n"] != 1:
            raise RuntimeError(
                "generate_user_batch is missing from the selected schema. "
                "Check DB_NAME in .env; schema.sql/procedures.sql use fake_user_generator."
            )
        print("[OK] Stored procedure generate_user_batch exists")

        required_tables = [
            "locales", "names", "titles", "street_names", "cities",
            "eye_colors", "email_domains", "generated_users",
        ]
        cursor.execute(
            """
            SELECT TABLE_NAME
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
            """
        )
        existing = {row["TABLE_NAME"] for row in cursor.fetchall()}
        missing = [name for name in required_tables if name not in existing]
        if missing:
            raise RuntimeError("Missing required table(s): " + ", ".join(missing))
        print("[OK] All required tables exist")

        for locale in ("en_US", "de_DE"):
            cursor.callproc("generate_user_batch", (locale, 987654321, 0, 3))
            rows = []
            for result in cursor.stored_results():
                rows.extend(result.fetchall())
            if len(rows) != 3:
                raise RuntimeError(f"{locale}: expected 3 generated rows, got {len(rows)}")
            if any(not row.get("full_name") or not row.get("email") for row in rows):
                raise RuntimeError(f"{locale}: generated rows have missing name/email")
            print(f"[OK] {locale}: generated {len(rows)} users")

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
