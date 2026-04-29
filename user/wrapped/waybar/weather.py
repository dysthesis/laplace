#!/usr/bin/env python
from ftplib import FTP
from pathlib import Path
import argparse
import json
import os
import re
import sys
import time
import xml.etree.ElementTree as ET


class WeatherError(Exception):
    pass


def debug(args, message):
    if args.debug:
        print(message, file=sys.stderr)


def cache_path(filename):
    root = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return root / "waybar-weather" / filename


def read_cache(path):
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return None


def write_cache(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)


def download_xml_from_bom_ftp(args, filename):
    ftp = None
    chunks = []

    try:
        debug(args, "Opening connection to BOM")
        ftp = FTP("ftp.bom.gov.au", timeout=args.timeout)
        ftp.login()
        ftp.cwd("anon/gen/fwo")

        debug(args, "Downloading forecast XML")
        ftp.retrbinary(f"RETR {filename}", chunks.append)
        return b"".join(chunks).decode("utf-8")
    except Exception as exc:
        raise WeatherError(f"failed to retrieve {filename}: {exc}") from exc
    finally:
        if ftp is not None:
            try:
                ftp.quit()
            except Exception:
                pass


def load_xml(args, filename):
    path = cache_path(filename)
    cached = read_cache(path)

    if cached is not None:
        age = time.time() - path.stat().st_mtime
        if age <= args.cache_ttl:
            debug(args, f"Using fresh cache: {path}")
            return cached, False

    try:
        xml_content = download_xml_from_bom_ftp(args, filename)
        write_cache(path, xml_content)
        return xml_content, False
    except WeatherError:
        if cached is not None:
            debug(args, f"Using stale cache: {path}")
            return cached, True
        raise


def map_icon_code_to_description(icon_code):
    icon_mapping = {
        "1": "☀️",
        "2": "🌙",
        "3": "🌤️",
        "4": "☁️",
        "6": "🌫️",
        "8": "🌧️",
        "9": "💨",
        "10": "🌫️",
        "11": "🌧️",
        "12": "🌧️",
        "13": "🌬️",
        "14": "❄️",
        "15": "❄️",
        "16": "⛈️",
        "17": "🌧️",
        "18": "🌧️",
        "19": "🌀",
    }

    return icon_mapping.get(icon_code, "?")


def extract_forecast(args, xml_content):
    debug(args, "Extracting forecast data")
    root = ET.fromstring(xml_content)

    for forecast_period in root.findall(".//forecast-period"):
        max_temp_element = forecast_period.find(
            './/element[@type="air_temperature_maximum"]'
        )
        icon_code_element = forecast_period.find(
            './/element[@type="forecast_icon_code"]'
        )
        precis_element = forecast_period.find('.//text[@type="precis"]')

        if all(
            [
                max_temp_element is not None,
                icon_code_element is not None,
                precis_element is not None,
            ]
        ):
            return {
                "temperature": max_temp_element.text,
                "icon": map_icon_code_to_description(icon_code_element.text),
                "precis": precis_element.text.rstrip("."),
            }

    raise WeatherError("forecast XML did not contain expected forecast fields")


def print_waybar_json(forecast, stale):
    text = f"{forecast['icon']} {forecast['temperature']}°C {forecast['precis']}"
    payload = {
        "text": text,
        "tooltip": "Stale cached forecast" if stale else forecast["precis"],
        "class": "stale" if stale else "normal",
    }
    print(json.dumps(payload))


def print_waybar_error(message):
    print(
        json.dumps(
            {
                "text": " Weather",
                "tooltip": message,
                "class": "error",
            }
        )
    )


def print_forecast(forecast, stale):
    prefix = "Stale forecast" if stale else "Forecast"
    print(f"\n\n<---{prefix}--->\n")
    print(f"Temperature: {forecast['temperature']}°C")
    print(f"Current Conditions: {forecast['precis']}")
    print(f"Icon: {forecast['icon']}")


def check_product_id_pattern(product_id):
    pattern = re.compile(r"^IDN\d{5}$")
    return bool(pattern.match(product_id))


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Get weather forecast from BOM and format it",
    )
    parser.add_argument("-d", "--debug", action="store_true", help="print debug info")
    parser.add_argument("--timeout", type=int, default=10, help="FTP timeout seconds")
    parser.add_argument(
        "--cache-ttl",
        type=int,
        default=1800,
        help="fresh cache lifetime seconds",
    )
    parser.add_argument(
        "output",
        nargs="?",
        choices=["terminal", "waybar"],
        help="Format for the output, use terminal for testing",
    )
    parser.add_argument(
        "product_id",
        nargs="?",
        help="The product ID you want a forecast for, checkout the README for help",
    )

    args = parser.parse_args()
    if not args.output:
        parser.error("an output type is required, options: terminal, waybar")
    if not args.product_id:
        parser.error("a Product ID is required to get relevant weather data")
    if not check_product_id_pattern(args.product_id):
        parser.error("Product ID must match IDNxxxxx where x is a number")

    ftp_filename = args.product_id + ".xml"

    try:
        xml_content, stale = load_xml(args, ftp_filename)
        forecast = extract_forecast(args, xml_content)
    except Exception as exc:
        if args.output == "waybar":
            print_waybar_error(str(exc))
            return 0
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    if args.output == "terminal":
        print_forecast(forecast, stale)
    elif args.output == "waybar":
        print_waybar_json(forecast, stale)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
