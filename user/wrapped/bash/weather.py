#!/usr/bin/env python
from ftplib import FTP
import xml.etree.ElementTree as ET
import argparse
import re


def download_xml_from_bom_ftp(args, filename):
    try:
        if args.debug:
            print("[-] Opening connection to BOM")

        with FTP("ftp.bom.gov.au") as ftp:
            ftp.login()
            ftp.cwd("anon/gen/fwo")

            if args.debug:
                print("[-] Starting download of latest observations")

            xml_content = ""

            def append_data(data):
                nonlocal xml_content
                xml_content += data.decode("utf-8")

            ftp.retrbinary("RETR " + filename, append_data)

        if args.debug:
            print("[+] Latest observations downloaded successfully!")

        return xml_content
    except Exception as e:
        print(f"[!] An error occurred while retrieving XML: {e}")

def map_icon_code_to_description(icon_code):
    icon_mapping = {
        '1': '☀️',  # Sunny
        '2': '🌙',  # Clear (Night)
        '3': '🌤️',  # Mostly sunny/partly cloudy
        '4': '☁️',  # Cloudy
        '6': '🌫️',  # Hazy
        '8': '🌧️',  # Light rain
        '9': '💨',  # Windy
        '10': '🌫️',  # Fog
        '11': '🌧️',  # Shower
        '12': '🌧️',  # Rain
        '13': '🌬️',  # Dusty
        '14': '❄️',  # Frost
        '15': '❄️',  # Snow
        '16': '⛈️',  # Storm
        '17': '🌧️',  # Light shower
        '18': '🌧️',  # Heavy shower
        '19': '🌀',  # Tropical Cyclone
    }

    return icon_mapping.get(icon_code, "Unknown icon")


def extract_forecast(args, xml_content):
    if args.debug:
        print("[-] Starting extraction of latest observation data")

    root = ET.fromstring(xml_content)

    for forecast_period in root.findall(".//forecast-period"):
        max_temp_element = forecast_period.find(
            './/element[@type="air_temperature_maximum"]'
        )
        icon_code_element = forecast_period.find(
            './/element[@type="forecast_icon_code"]'
        )
        precis_element = forecast_period.find('.//text[@type="precis"]')

        max_temp = max_temp_element.text if max_temp_element is not None else None
        icon_code = icon_code_element.text if icon_code_element is not None else None
        precis = precis_element.text if precis_element is not None else None

        if max_temp is not None and icon_code is not None and precis is not None:
            icon = map_icon_code_to_description(icon_code)

            if args.debug:
                print("[+] Successfully extracted Temp, Precis and Icon Code")

            return {
                "temperature": max_temp,
                "icon": icon,
                "precis": precis.rstrip("."),
            }


def print_dwl(args, forecast):
    if args.debug:
        print("[-] Converting observation data to dwl output")

    print(f"{forecast['icon']} {forecast['temperature']}°C {forecast['precis']}")


def print_forecast(forecast):
    print("\n\n<---Forecast--->\n")
    print(f"Temperature: {forecast['temperature']}°C")
    print(f"Current Conditions: {forecast['precis']}")
    print(f"Icon: {forecast['icon']}")


def check_product_id_pattern(product_id):
    pattern = re.compile(r"^IDN\d{5}$")
    return bool(pattern.match(product_id))


def main():
    # Argument setup and management
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Get weather forecast from BOM and format it",
    )

    parser.add_argument("-d", "--debug", action="store_true", help="print debug info")

    parser.add_argument(
        "output",
        nargs="?",
        choices=["terminal", "dwl"],
        help="Format for the output, use terminal for testing",
    )

    parser.add_argument(
        "product_id",
        nargs="?",
        help="The product ID you want a forecast for, checkout the README for help",
    )

    args = parser.parse_args()

    if not args.output:
        print("Error: An output type is required, options: (terminal, dwl)")
        print("Use --help for help")
        exit()

    if not args.product_id:
        print("Error: A Product ID is required to get relevant weather data")
        print("Use --help for help")
        exit()

    if not check_product_id_pattern(args.product_id):
        print(
            "Error: Product ID's must match this format: 'IDNxxxxx' where 'x' is a number"
        )
        print("Use --help for help")
        exit()

    # Weather script
    ftp_filename = args.product_id + ".xml"

    if args.debug:
        print("[~] Debug mode active")

    if args.output == "terminal":
        xml_content = download_xml_from_bom_ftp(args, ftp_filename)

        if xml_content:
            forecast = extract_forecast(args, xml_content)
            print_forecast(forecast)
        else:
            print("[!] Failed to download XML file, check the product ID")

    if args.output == "dwl":
        xml_content = download_xml_from_bom_ftp(args, ftp_filename)

        if xml_content:
            forecast = extract_forecast(args, xml_content)
            print_dwl(args, forecast)
        else:
            print("[!] Failed to download XML file, check the product ID")


if __name__ == "__main__":
    main()
