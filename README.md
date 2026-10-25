# Fake User Generator

A web-based fake user profile generator built with **MySQL stored procedures**, Flask, and HTML. MySQL handles profile generation and data persistence; Flask provides the web interface and reads the generated records.

## Features

- Supports English (US) and German (Germany) locales: `en_US` and `de_DE`.
- Deterministic generation using a locale, seed, and batch parameters.
- Generate a batch of users and navigate to the next batch.
- Generates names, titles, street addresses, cities, regions, postal codes, coordinates, birth dates, height, weight, eye color, phone numbers, and email addresses.
- Uses lookup tables to support adding more locale-specific data.
- Stores generated profiles in MySQL.
- Responsive browser interface built with Flask.

## Technology Stack

- Python
- Flask
- MySQL 8
- mysql-connector-python
- python-dotenv
- Gunicorn

## Project Structure

```text
fake_user_generator/
├── app.py
├── schema.sql
├── procedures.sql
├── procedures_backup.sql
├── requirements.txt
├── .env
├── .gitignore
└── templates/
    └── index.html
```

## Requirements

- Python 3
- MySQL Server 8
- A database user with the required permissions
- A modern web browser

## Installation

### 1. Clone or open the project

Open the project directory in a terminal.

```powershell
cd F:\fake_user_generator
```

### 2. Create and activate a virtual environment

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

If PowerShell blocks script execution, use Command Prompt activation or run the app using the virtual environment's Python executable.

### 3. Install Python dependencies

```powershell
python -m pip install -r requirements.txt
```

### 4. Create the database

Open MySQL and run:

```sql
CREATE DATABASE IF NOT EXISTS fake_user_generator
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;
```

Create a database user and grant only the permissions required by the application. Use a strong password and do not commit credentials to source control.

### 5. Create the database tables

From the project directory, run this in PowerShell:

```powershell
cmd /c """C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"" --default-character-set=utf8mb4 -u root -p fake_user_generator < schema.sql"
```

Enter the MySQL root password when prompted.

### 6. Install the stored procedures

```powershell
cmd /c """C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"" --default-character-set=utf8mb4 -u root -p fake_user_generator < procedures.sql"
```

Use the correct MySQL executable path if MySQL is installed elsewhere.

### 7. Configure environment variables

Create a local `.env` file in the project root:

```dotenv
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=fake_user_generator
DB_USER=fakeapp
DB_PASSWORD=replace_with_your_database_password
```

The database user and password must match the account configured in MySQL. Never commit `.env` or real credentials to Git.

### 8. Run the application

```powershell
python app.py
```

Open:

http://127.0.0.1:5000

## Usage

1. Select a locale (`en_US` or `de_DE`).
2. Enter a seed value.
3. Select a batch index and batch size.
4. Click **Generate Users** to generate a batch.
5. Click **Next Batch** to request the next batch.
6. Review the generated profiles in the results table.

For reproducibility, use the same locale, seed, batch index, and batch size.

## Stored Procedure

The main generation procedure is:

```sql
CALL generate_user_batch('en_US', 654321, 0, 10);
```

Parameters:

- Locale: `en_US` or `de_DE`
- Seed: a non-negative integer
- Batch index: a non-negative integer
- Batch size: an integer from 1 to 1000

The procedure validates input, uses locale lookup tables, generates profile fields, stores records in MySQL, and returns the requested batch.

## Testing

The following checks were performed during development:

- English batch reproducibility: the first 10 profiles matched when the same seed and batch were generated again.
- German locale generation: German names, titles, street names, cities, and other profile fields were generated.
- Unicode correction: the malformed German eye-color value was corrected in the lookup table and existing generated records.
- Next Batch: the web interface advanced from batch index 0 to batch index 1 and displayed user indices 10–19 for a batch size of 10.
- Height and weight distribution: a sample of 5,000 English profiles was examined. The observed distributions were approximately bell-shaped.

## Preliminary Performance Measurements

Development measurements, including procedure calls and returned-row/client overhead:

| Batch size | Elapsed time | Approximate throughput |
|---:|---:|---:|
| 100 | 2.914 s | 34.32 users/s |
| 500 | 6.209 s | 80.53 users/s |
| 1,000 | 12.269 s | 81.50 users/s |

These are preliminary measurements from the development environment, not isolated database-engine benchmarks. Performance can vary with hardware, database configuration, and client overhead.

## Known Limitations

- Generated names, addresses, phone numbers, and emails are synthetic test data and are not guaranteed to identify real people or represent deliverable contact details.
- Coordinates are generated globally and are not necessarily geographically consistent with the generated city.
- Performance figures are preliminary and should be measured again under a documented benchmark procedure.
- Only the `en_US` and `de_DE` locales have been tested so far.

## Extending Locale Data

Locale-specific values are stored in lookup tables such as `locales`, `names`, `titles`, `street_names`, `cities`, `eye_colors`, and `email_domains`.

To add a locale, add the locale record and its required lookup data, then confirm that the stored procedure supports that locale before generating profiles.

## Security

- Keep `.env` out of version control.
- Do not publish database passwords.
- Do not expose MySQL directly to the public internet.
- For production deployment, configure environment variables and database permissions securely.
