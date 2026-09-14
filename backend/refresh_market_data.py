import csv
import os
import time
from pathlib import Path

import requests
from dotenv import load_dotenv


# ============================================================
# CONFIGURATION
# ============================================================

load_dotenv()

API_KEY = os.getenv("DATA_GOV_IN_API_KEY")

RESOURCE_URL = (
    "https://api.data.gov.in/resource/"
    "9ef84268-d588-465a-a308-a864a43d0070"
)

BASE_DIR = Path(__file__).resolve().parent

FINAL_CSV = BASE_DIR / "market_prices.csv"
TEMP_CSV = BASE_DIR / "market_prices_new.csv"

LIMIT = 100
REQUEST_TIMEOUT = 30
MAX_RETRIES = 3


# ============================================================
# VALIDATE API KEY
# ============================================================

if not API_KEY:
    raise RuntimeError(
        "DATA_GOV_IN_API_KEY is missing from .env"
    )


# ============================================================
# DOWNLOAD ALL CURRENT RECORDS
# ============================================================

def download_market_data():

    all_records = []

    offset = 0

    print()
    print("==========================================")
    print("CROPNEXA DAILY MARKET DATA REFRESH")
    print("==========================================")

    while True:

        params = {
            "api-key": API_KEY,
            "format": "json",
            "limit": LIMIT,
            "offset": offset,
        }

        print(
            f"Downloading records "
            f"{offset + 1} onward..."
        )

        response = None

        for attempt in range(1, MAX_RETRIES + 1):

            try:

                response = requests.get(
                    RESOURCE_URL,
                    params=params,
                    timeout=REQUEST_TIMEOUT,
                )

                response.raise_for_status()

                break

            except requests.RequestException as error:

                print(
                    f"Attempt {attempt} failed: {error}"
                )

                if attempt == MAX_RETRIES:
                    raise

                time.sleep(3)

        data = response.json()

        records = data.get(
            "records",
            []
        )

        if not records:
            break

        all_records.extend(records)

        print(
            f"Downloaded {len(all_records)} records"
        )

        if len(records) < LIMIT:
            break

        offset += LIMIT

    return all_records


# ============================================================
# WRITE CSV
# ============================================================

def write_csv(records):

    if not records:
        raise RuntimeError(
            "Government API returned zero records."
        )

    fieldnames = [
        "State",
        "District",
        "Market",
        "Commodity",
        "Variety",
        "Grade",
        "Arrival_Date",
        "Min_x0020_Price",
        "Max_x0020_Price",
        "Modal_x0020_Price",
    ]

    with open(
        TEMP_CSV,
        "w",
        encoding="utf-8",
        newline="",
    ) as file:

        writer = csv.DictWriter(
            file,
            fieldnames=fieldnames,
        )

        writer.writeheader()

        for record in records:

            writer.writerow({
                "State":
                    record.get("state", ""),

                "District":
                    record.get("district", ""),

                "Market":
                    record.get("market", ""),

                "Commodity":
                    record.get("commodity", ""),

                "Variety":
                    record.get("variety", ""),

                "Grade":
                    record.get("grade", ""),

                "Arrival_Date":
                    record.get("arrival_date", ""),

                "Min_x0020_Price":
                    record.get("min_price", ""),

                "Max_x0020_Price":
                    record.get("max_price", ""),

                "Modal_x0020_Price":
                    record.get("modal_price", ""),
            })


# ============================================================
# VALIDATE CSV
# ============================================================

def validate_csv():

    if not TEMP_CSV.exists():
        raise RuntimeError(
            "Temporary CSV was not created."
        )

    if TEMP_CSV.stat().st_size == 0:
        raise RuntimeError(
            "Temporary CSV is empty."
        )

    with open(
        TEMP_CSV,
        "r",
        encoding="utf-8",
        newline="",
    ) as file:

        reader = csv.DictReader(file)

        rows = list(reader)

    if not rows:
        raise RuntimeError(
            "Temporary CSV contains no data."
        )

    required_columns = {
        "State",
        "District",
        "Market",
        "Commodity",
        "Variety",
        "Grade",
        "Arrival_Date",
        "Min_x0020_Price",
        "Max_x0020_Price",
        "Modal_x0020_Price",
    }

    actual_columns = set(
        reader.fieldnames or []
    )

    missing = (
        required_columns - actual_columns
    )

    if missing:
        raise RuntimeError(
            f"Missing columns: {missing}"
        )

    print(
        f"CSV validation successful: "
        f"{len(rows)} records"
    )


# ============================================================
# REPLACE OLD CSV SAFELY
# ============================================================

def replace_csv():

    if FINAL_CSV.exists():

        backup_csv = (
            BASE_DIR / "market_prices_backup.csv"
        )

        FINAL_CSV.replace(
            backup_csv
        )

        print(
            "Previous CSV backed up."
        )

    TEMP_CSV.replace(
        FINAL_CSV
    )

    print(
        "New market_prices.csv installed."
    )


# ============================================================
# MAIN
# ============================================================

def main():

    try:

        records = download_market_data()

        print(
            f"Total records downloaded: "
            f"{len(records)}"
        )

        write_csv(records)

        validate_csv()

        replace_csv()

        print()
        print(
            "=========================================="
        )
        print(
            "CROPNEXA: DAILY REFRESH SUCCESS"
        )
        print(
            "=========================================="
        )

    except Exception as error:

        print()
        print(
            "=========================================="
        )
        print(
            "CROPNEXA: DAILY REFRESH FAILED"
        )
        print(
            "=========================================="
        )

        print(
            "ERROR:",
            error
        )

        print(
            "Existing market_prices.csv was NOT replaced."
        )

        if TEMP_CSV.exists():
            TEMP_CSV.unlink()

        raise


if __name__ == "__main__":
    main()