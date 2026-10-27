import os
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, render_template, request
import mysql.connector
from mysql.connector import Error

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=BASE_DIR / ".env", override=False)

app = Flask(__name__)

SUPPORTED_LOCALES = {
    "en_US": "English (USA)",
    "de_DE": "German (Germany)",
}
MAX_MYSQL_BIGINT = 9_223_372_036_854_775_807


def get_db_connection():
    """Connect to the configured MySQL schema, optionally using verified TLS."""
    ssl_ca = os.getenv("DB_SSL_CA", "").strip()

    connection_options = {
        "host": os.getenv("DB_HOST", "127.0.0.1").strip(),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "root").strip(),
        "password": os.getenv("DB_PASSWORD", ""),
        "database": os.getenv("DB_NAME", "fake_user_generator").strip(),
        "charset": "utf8mb4",
        "connection_timeout": 15,
        "autocommit": False,
    }

    if ssl_ca:
        ca_path = Path(ssl_ca)
        if not ca_path.is_absolute():
            ca_path = BASE_DIR / ca_path
        if not ca_path.is_file():
            raise FileNotFoundError(
                f"DB_SSL_CA points to a file that does not exist: {ca_path}"
            )
        connection_options.update({
            "ssl_ca": str(ca_path),
            "ssl_verify_cert": True,
            "ssl_verify_identity": True,
        })

    return mysql.connector.connect(**connection_options)


@app.route("/", methods=["GET", "POST"])
def index():
    users = []
    error = None
    form_data = {
        "locale": "en_US",
        "seed": "12345",
        "batch_index": "0",
        "batch_size": "10",
    }

    if request.method == "POST":
        for key in form_data:
            form_data[key] = request.form.get(key, form_data[key]).strip()

        try:
            locale = form_data["locale"]
            seed = int(form_data["seed"])
            batch_index = int(form_data["batch_index"])
            batch_size = int(form_data["batch_size"])

            if locale not in SUPPORTED_LOCALES:
                raise ValueError("Please select a supported locale.")
            if not 0 <= seed <= MAX_MYSQL_BIGINT:
                raise ValueError("Seed must be between 0 and the MySQL BIGINT limit.")
            if not 0 <= batch_index <= MAX_MYSQL_BIGINT:
                raise ValueError("Batch index must be non-negative and within the MySQL BIGINT limit.")
            if not 1 <= batch_size <= 1000:
                raise ValueError("Batch size must be between 1 and 1000.")
            if batch_index * batch_size + batch_size - 1 > MAX_MYSQL_BIGINT:
                raise ValueError("This batch index and size exceed the MySQL BIGINT limit.")

            connection = get_db_connection()
            try:
                cursor = connection.cursor(dictionary=True)
                try:
                    cursor.callproc(
                        "generate_user_batch",
                        (locale, seed, batch_index, batch_size),
                    )
                    for result in cursor.stored_results():
                        users = result.fetchall()

                    # Persist INSERT/UPDATE statements executed by the procedure.
                    connection.commit()
                finally:
                    cursor.close()
            finally:
                connection.close()

            if not users:
                error = (
                    "The database procedure ran but returned no users. "
                    "Check that the selected locale has lookup data."
                )

        except ValueError as exc:
            error = str(exc)
        except FileNotFoundError:
            app.logger.exception("Database CA certificate configuration failed")
            error = "The database SSL certificate file is missing. Check DB_SSL_CA in .env."
        except Error:
            app.logger.exception("Database operation failed")
            error = (
                "Could not generate users. The full reason is in the VS Code "
                "terminal. Check DB_NAME, credentials, SSL settings, and that "
                "generate_user_batch exists in the selected database."
            )
        except Exception:
            app.logger.exception("Unexpected error generating users")
            error = "Something went wrong. Check the VS Code terminal for details."

    return render_template(
        "index.html",
        locales=[
            {"locale_code": code, "language_name": name}
            for code, name in SUPPORTED_LOCALES.items()
        ],
        users=users,
        error=error,
        form_data=form_data,
    )


@app.route("/health")
def health():
    """A minimal health check that also verifies the required procedure exists."""
    connection = None
    cursor = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute("SELECT DATABASE(), @@hostname")
        database_name, mysql_server = cursor.fetchone()

        cursor.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.ROUTINES
            WHERE ROUTINE_SCHEMA = DATABASE()
              AND ROUTINE_NAME = 'generate_user_batch'
              AND ROUTINE_TYPE = 'PROCEDURE'
            """
        )
        procedure_exists = cursor.fetchone()[0] == 1

        if not procedure_exists:
            app.logger.error(
                "Health check: generate_user_batch is missing from schema %s",
                database_name,
            )
            return {
                "status": "error",
                "database": "connected",
                "database_name": database_name,
                "mysql_server": mysql_server,
                "procedure": "missing",
            }, 503

        return {
            "status": "ok",
            "database": "connected",
            "database_name": database_name,
            "mysql_server": mysql_server,
            "procedure": "installed",
        }
    except (Error, ValueError, FileNotFoundError):
        app.logger.exception("Database health check failed")
        return {
            "status": "error",
            "database": "disconnected_or_misconfigured",
            "procedure": "not_checked",
        }, 503
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG", "false").lower() == "true")
