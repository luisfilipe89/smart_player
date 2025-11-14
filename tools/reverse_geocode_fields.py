#!/usr/bin/env python3
"""Reverse-geocode features in GeoJSON files from assets/fields/input/.

Processes all files matching the pattern <sport>_overpass.geojson and outputs
enhanced GeoJSON files to assets/fields/output/ with the name format <sport>.geojson.

Usage:
  python tools/reverse_geocode_fields.py
"""

from __future__ import annotations

import json
import math
import pathlib
import shutil
import sys
import time
import typing as t
from dataclasses import dataclass
from urllib import parse, request


NOMINATIM_ENDPOINT = "https://nominatim.openstreetmap.org/reverse"
INPUT_DIR = pathlib.Path("assets/fields/input")
OUTPUT_DIR = pathlib.Path("assets/fields/output")
PROCESSED_DIR = pathlib.Path("assets/fields/processed")
DELAY_SECONDS = 1.1  # Keep >=1s for public Nominatim


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


def format_micro_short_address(address: dict[str, t.Any] | None) -> str | None:
    """Return only the road/pedestrian/footway name without any other details."""
    if not address:
        return None
    return (
        address.get("road")
        or address.get("pedestrian")
        or address.get("footway")
        or None
    )


def process_geojson_file(input_path: pathlib.Path, output_path: pathlib.Path) -> int:
    """Process a single GeoJSON file and write the enhanced version."""
    print(f"Processing {input_path.name}...", file=sys.stderr)

    with input_path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    updated_features = []
    feature_count = len(data.get("features", []))
    processed = 0

    for feature in data.get("features", []):
        identifier = feature.get("id") or feature.get("properties", {}).get("@id")
        try:
            lon, lat = feature_point(feature["geometry"])
        except Exception as exc:
            print(f"  Skipping feature {identifier}: failed to determine point ({exc})", file=sys.stderr)
            updated_features.append(feature)
            continue

        response = reverse_geocode(lon, lat, delay_seconds=DELAY_SECONDS)
        processed += 1
        if processed % 10 == 0:
            print(f"  Processed {processed}/{feature_count} features...", file=sys.stderr)

        address = response.address
        short_address = format_short_address(address)
        super_short_address = format_super_short_address(address)
        micro_short_address = format_micro_short_address(address)

        properties = dict(feature.get("properties", {}))
        if response.display_name:
            properties["address_display_name"] = response.display_name
        if short_address:
            properties["address_short"] = short_address
        elif "address_short" in properties:
            properties.pop("address_short")
        if super_short_address:
            properties["address_super_short"] = super_short_address
        elif "address_super_short" in properties:
            properties.pop("address_super_short")
        if micro_short_address:
            properties["address_micro_short"] = micro_short_address
        elif "address_micro_short" in properties:
            properties.pop("address_micro_short")

        feature_copy = dict(feature)
        feature_copy["properties"] = properties
        updated_features.append(feature_copy)

    # Preserve all root-level properties (including overpass_query if present)
    data_copy = dict(data)
    data_copy["features"] = updated_features

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as fh:
        json.dump(data_copy, fh, ensure_ascii=False, indent=2)

    print(f"  Completed! Output written to {output_path}", file=sys.stderr)
    return 0


def move_to_processed(input_path: pathlib.Path) -> None:
    """Move a processed input file to the processed directory."""
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    processed_path = PROCESSED_DIR / input_path.name
    shutil.move(str(input_path), str(processed_path))
    print(f"  Moved {input_path.name} to {PROCESSED_DIR}", file=sys.stderr)


def main() -> int:
    """Process all <sport>_overpass.geojson files from input directory."""
    if not INPUT_DIR.exists():
        print(f"Error: Input directory not found: {INPUT_DIR}", file=sys.stderr)
        return 1

    # Find all files matching <sport>_overpass.geojson pattern
    input_files = list(INPUT_DIR.glob("*_overpass.geojson"))
    
    if not input_files:
        print(f"No files matching pattern '*_overpass.geojson' found in {INPUT_DIR}", file=sys.stderr)
        return 1

    print(f"Found {len(input_files)} file(s) to process", file=sys.stderr)

    for input_file in input_files:
        # Extract sport name: <sport>_overpass.geojson -> <sport>
        sport_name = input_file.stem.replace("_overpass", "")
        output_file = OUTPUT_DIR / f"{sport_name}.geojson"

        result = process_geojson_file(input_file, output_file)
        if result != 0:
            return result

        # Move processed file to processed directory
        move_to_processed(input_file)

    print("All files processed successfully!", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        raise SystemExit(130)
