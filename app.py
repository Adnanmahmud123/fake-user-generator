
import os

from flask import Flask, render_template, request
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import Error

load_dotenv()

app = Flask(__name__)

SUPPORTED_LOCALES = {
    "en_US": "English (USA)",
    "de_DE": "German (Germany)",
}


def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "fake_user_generator"),
        charset="utf8mb4",
    )


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

            if seed < 0:
                raise ValueError("Seed must be non-negative.")

            if batch_index < 0:
                raise ValueError("Batch index must be non-negative.")

            if not 1 <= batch_size <= 1000:
                raise ValueError("Batch size must be between 1 and 1000.")

            connection = get_db_connection()

            try:
                cursor = connection.cursor(dictionary=True)
                cursor.callproc(
                    "generate_user_batch",
                    (locale, seed, batch_index, batch_size),
                )

                for result in cursor.stored_results():
                    users = result.fetchall()

                cursor.close()
            finally:
                connection.close()

        except ValueError as exc:
            error = str(exc)
        except Error:
            app.logger.exception("Database operation failed")
            error = (
                "Could not generate users. Check that MySQL is running, "
                "the database credentials are correct, and the stored "
                "procedure is installed."
            )
        except Exception:
            app.logger.exception("Unexpected error generating users")
            error = "Something went wrong. Check the server terminal."

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
    try:
        connection = get_db_connection()
        connection.close()
        return {"status": "ok", "database": "connected"}
    except Error:
        app.logger.exception("Database health check failed")
        return {"status": "error", "database": "disconnected"}, 503


if __name__ == "__main__":
    app.run(debug=True)
