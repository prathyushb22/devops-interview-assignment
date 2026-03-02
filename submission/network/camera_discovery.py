#!/usr/bin/env python3
"""
camera_discovery.py — ONVIF Camera Discovery Tool

TASK: Implement a camera discovery script that:
  1. Reads an ONVIF WS-Discovery XML response (like data/onvif_mock_response.xml)
  2. Parses the XML to extract camera information
  3. Outputs a JSON array of discovered cameras
  4. Handles timeouts and malformed XML gracefully

Requirements:
  - Parse the ONVIF ProbeMatch elements
  - Extract: endpoint address (UUID), hardware model, name, location, service URL
  - Output valid JSON to stdout
  - Accept --input flag for XML file path (default: stdin)
  - Accept --timeout flag for discovery timeout in seconds
  - Handle errors gracefully (timeout, parse errors, missing fields)

Example output:
[
  {
    "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "model": "P3265-LVE",
    "name": "AXIS P3265-LVE",
    "location": "LoadingDockA",
    "service_url": "http://10.50.20.101:80/onvif/device_service",
    "ip": "10.50.20.101"
  }
]
"""

import argparse
import json
import sys
import re
import threading
import urllib.parse
import xml.etree.ElementTree as ET

NS = {
    "s": "http://www.w3.org/2003/05/soap-envelope",
    "a": "http://schemas.xmlsoap.org/ws/2004/08/addressing",
    "d": "http://schemas.xmlsoap.org/ws/2005/04/discovery",
    "dn": "http://www.onvif.org/ver10/network/wsdl",
}

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Parse ONVIF WS-Discovery XML and output JSON.")
    parser.add_argument("--input", default=None, help="Path to XML file (default: read from stdin).")
    parser.add_argument("--timeout", type=int, default=5, help="Timeout in seconds (default: 5).")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be a positive integer")
    return args

def _unquote(v: str) -> str:
    return urllib.parse.unquote((v or "").strip())


def _scope_value(scopes: str, key: str) -> str:
    # Example: onvif://www.onvif.org/name/AXIS%20P3265-LVE
    m = re.search(rf"onvif://www\.onvif\.org/{re.escape(key)}/([^\s]+)", scopes or "")
    return _unquote(m.group(1)) if m else ""


def _extract_uuid(address: str) -> str:
    addr = (address or "").strip()
    return addr.split(":", 2)[2] if addr.lower().startswith("urn:uuid:") else addr


def _extract_service_url(xaddrs: str) -> str:
    parts = (xaddrs or "").strip().split()
    return parts[0].strip() if parts else ""


def _extract_ip(service_url: str) -> str:
    try:
        return urllib.parse.urlparse(service_url).hostname or ""
    except Exception:
        return ""

def parse_onvif_response(xml_content):
    """Parse ONVIF WS-Discovery XML and return list of camera dicts."""
    try:
        root = ET.fromstring(xml_content)
    except ET.ParseError as e:
        raise ValueError(f"Malformed XML: {e}") from e

    cameras = []
    for pm in root.findall(".//d:ProbeMatch", NS):
        address = pm.findtext("a:EndpointReference/a:Address", default="", namespaces=NS)
        uuid_val = _extract_uuid(address)

        xaddrs = pm.findtext("d:XAddrs", default="", namespaces=NS)
        service_url = _extract_service_url(xaddrs)

        scopes = pm.findtext("d:Scopes", default="", namespaces=NS)
        model = _scope_value(scopes, "hardware")
        name = _scope_value(scopes, "name") or model
        location = _scope_value(scopes, "location")

        cameras.append(
            {
                "uuid": uuid_val,
                "model": model,
                "name": name,
                "location": location,
                "service_url": service_url,
                "ip": _extract_ip(service_url) if service_url else "",
            }
        )

    return cameras

def _run_with_timeout(fn, timeout_s: int):
    """Run fn() with a hard timeout; raise TimeoutError if exceeded."""
    result = {}
    error = {}

    def target():
        try:
            result["value"] = fn()
        except BaseException as e:  # noqa: BLE001
            error["err"] = e

    t = threading.Thread(target=target, daemon=True)
    t.start()
    t.join(timeout_s)

    if t.is_alive():
        raise TimeoutError(f"Timed out after {timeout_s}s")

    if "err" in error:
        raise error["err"]

    return result.get("value")

def main():

  args = parse_args()
  try:
    def read_xml():
      if args.input:
          with open(args.input, "r", encoding="utf-8") as f:
            return f.read()
      return sys.stdin.read()

    xml_content = _run_with_timeout(read_xml, args.timeout)
    cameras = _run_with_timeout(lambda: parse_onvif_response(xml_content), args.timeout)

    json.dump(cameras, sys.stdout, indent=2)
    sys.stdout.write("\n")
  except TimeoutError as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(124)
  except ValueError as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(2)
  except Exception as e:  # noqa: BLE001
    print(json.dumps({"error": f"Unexpected error: {e}"}), file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
