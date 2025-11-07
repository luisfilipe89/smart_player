#!/usr/bin/env python3
"""Reverse-geocode features in a GeoJSON file.

Usage:
  python tools/reverse_geocode_fields.py \
      assets/fields/football_leisure_pitch, sport_soccer, access_yes, equipment_yes.geojson \
      --output assets/fields/football_leisure_pitch, sport_soccer, access_yes, equipment_yes_with_addresses.geojson

By default, results are also cached in JSON so repeated runs do not hit the API again.
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys
import time
import typing as t
from dataclasses import dataclass
from urllib import parse, request


NOMINATIM_ENDPOINT = "https://nominatim.openstreetmap.org/reverse"


def _build_user_agent() -> str:
    # Keep contact info configurable so devs can customize without editing code.
    return "smart-player-reverse-geocoder/1.0 (contact: luisfccfigueiredo@gmail.com)"


def _rate_limited_get(url: str, params: dict[str, t.Any], delay_seconds: float) -> dict[str, t.Any]:
    query = parse.urlencode(params)
    req = request.Request(
        f"{url}?{query}",
        headers={
            "User-Agent": _build_user_agent(),
            "Accept": "application/json",
        },
    )
    with request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    if delay_seconds:
        time.sleep(delay_seconds)
    return payload


def _centroid_of_polygon(ring: list[list[float]]) -> tuple[float, float]:
    """Return the centroid of a polygon ring using the area-weighted method."""
    if len(ring) < 3:
        raise ValueError("Polygon ring must have at least three coordinates")

    twice_area = 0.0
    cx = 0.0
    cy = 0.0

    for i in range(len(ring) - 1):
        x0, y0 = ring[i]
        x1, y1 = ring[i + 1]
        cross = x0 * y1 - x1 * y0
        twice_area += cross
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross

    if math.isclose(twice_area, 0.0):
        # Degenerate polygon; fall back to simple average.
        avg_x = sum(coord[0] for coord in ring[:-1]) / (len(ring) - 1)
        avg_y = sum(coord[1] for coord in ring[:-1]) / (len(ring) - 1)
        return avg_x, avg_y

    area = twice_area / 2.0
    cx /= (6.0 * area)
    cy /= (6.0 * area)
    return cx, cy


def feature_point(feature_geometry: dict[str, t.Any]) -> tuple[float, float]:
    geom_type = feature_geometry["type"].lower()
    coords = feature_geometry["coordinates"]

    if geom_type == "point":
        return coords[0], coords[1]
    if geom_type == "linestring":
        lon = sum(pt[0] for pt in coords) / len(coords)
        lat = sum(pt[1] for pt in coords) / len(coords)
        return lon, lat
    if geom_type == "polygon":
        # Use the exterior ring (first ring). Assume coordinates are closed.
        return _centroid_of_polygon(coords[0])
    if geom_type == "multipolygon":
        # Find the largest polygon by absolute area, use its centroid.
        best = None
        best_area = -1.0
        for polygon in coords:
            centroid = _centroid_of_polygon(polygon[0])
            ring = polygon[0]
            area = 0.0
            for i in range(len(ring) - 1):
                x0, y0 = ring[i]
                x1, y1 = ring[i + 1]
                area += x0 * y1 - x1 * y0
            area = abs(area) / 2.0
            if area > best_area:
                best_area = area
                best = centroid
        if best is None:
            raise ValueError("MultiPolygon had no valid polygons")
        return best

    raise NotImplementedError(f"Unsupported geometry type: {geom_type}")


@dataclass
class ReverseGeocodeResult:
    display_name: str | None
    address: dict[str, t.Any] | None


def reverse_geocode(lon: float, lat: float, delay_seconds: float) -> ReverseGeocodeResult:
    payload = _rate_limited_get(
        NOMINATIM_ENDPOINT,
        {
            "lat": lat,
            "lon": lon,
            "format": "jsonv2",
            "addressdetails": 1,
        },
        delay_seconds,
    )
    return ReverseGeocodeResult(
        display_name=payload.get("display_name"),
        address=payload.get("address"),
    )


def format_short_address(address: dict[str, t.Any] | None) -> str | None:
    if not address:
        return None
    parts = [
        address.get("road") or address.get("pedestrian") or address.get("footway"),
        address.get("house_number"),
        address.get("postcode"),
        address.get("city")
        or address.get("town")
        or address.get("village")
        or address.get("municipality"),
        address.get("country"),
    ]
    return ", ".join([part for part in parts if part]) or None


def format_super_short_address(address: dict[str, t.Any] | None) -> str | None:
    if not address:
        return None
    primary = (
        address.get("road")
        or address.get("pedestrian")
        or address.get("footway")
        or address.get("leisure")
        or address.get("amenity")
    )
    secondary = address.get("postcode") or (
        address.get("city")
        or address.get("town")
        or address.get("village")
        or address.get("municipality")
    )
    parts = [part for part in (primary, secondary) if part]
    return ", ".join(parts) or None


def load_cache(path: pathlib.Path) -> dict[str, dict[str, t.Any]]:
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {}


def save_cache(path: pathlib.Path, cache: dict[str, dict[str, t.Any]]) -> None:
    with path.open("w", encoding="utf-8") as fh:
        json.dump(cache, fh, indent=2, ensure_ascii=False)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("geojson", help="Path to the source GeoJSON file")
    parser.add_argument(
        "--output",
        help="Optional path to write enhanced GeoJSON. If omitted, results are printed to stdout.",
    )
    parser.add_argument(
        "--cache",
        default=".reverse_geocode_cache.json",
        help="Path to store API results for reuse.",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.1,
        help="Delay between requests in seconds. Keep >=1s for public Nominatim.",
    )
    args = parser.parse_args(argv)

    geojson_path = pathlib.Path(args.geojson)
    if not geojson_path.exists():
        parser.error(f"GeoJSON file not found: {geojson_path}")

    with geojson_path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    cache_path = pathlib.Path(args.cache)
    cache = load_cache(cache_path)

    updated_features = []

    for feature in data.get("features", []):
        identifier = feature.get("id") or feature.get("properties", {}).get("@id")
        try:
            lon, lat = feature_point(feature["geometry"])
        except Exception as exc:
            print(f"Skipping feature {identifier}: failed to determine point ({exc})", file=sys.stderr)
            updated_features.append(feature)
            continue

        cache_key = f"{lon:.6f},{lat:.6f}"
        if cache_key in cache:
            response = cache[cache_key]
        else:
            response = reverse_geocode(lon, lat, delay_seconds=args.delay).__dict__
            cache[cache_key] = response

        address = response.get("address")
        short_address = format_short_address(address)
        super_short_address = format_super_short_address(address)

        properties = dict(feature.get("properties", {}))
        if response.get("display_name"):
            properties["address_display_name"] = response["display_name"]
        if short_address:
            properties["address_short"] = short_address
        elif "address_short" in properties:
            properties.pop("address_short")
        if super_short_address:
            properties["address_super_short"] = super_short_address
        elif "address_super_short" in properties:
            properties.pop("address_super_short")

        feature_copy = dict(feature)
        feature_copy["properties"] = properties
        updated_features.append(feature_copy)

    data_copy = dict(data)
    data_copy["features"] = updated_features

    if args.output:
        output_path = pathlib.Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8") as fh:
            json.dump(data_copy, fh, ensure_ascii=False, indent=2)
    else:
        json.dump(data_copy, sys.stdout, ensure_ascii=False, indent=2)

    save_cache(cache_path, cache)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        raise SystemExit(130)

