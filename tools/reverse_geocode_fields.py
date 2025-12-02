#!/usr/bin/env python3
"""Reverse-geocode features in GeoJSON files from assets/fields/input/.

Processes all files matching the pattern <sport>_overpass.geojson and outputs
enhanced GeoJSON files to assets/fields/output/ with the name format <sport>.geojson.

Usage:
  python tools/reverse_geocode_fields.py
"""

from __future__ import annotations

import json
import pathlib
import sys
import time
import typing as t
from dataclasses import dataclass
from urllib import parse, request


NOMINATIM_ENDPOINT = "https://nominatim.openstreetmap.org/reverse"
INPUT_DIR = pathlib.Path("assets/fields/input")
OUTPUT_DIR = pathlib.Path("assets/fields/output")
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


def _average_of_polygon(ring: list[list[float]]) -> tuple[float, float]:
    """Return the average (arithmetic mean) of all coordinates in a polygon ring.
    
    This matches the coordinate extraction method used in the Flutter app.
    For closed polygons, the last point (duplicate of first) is excluded.
    """
    if len(ring) < 3:
        raise ValueError("Polygon ring must have at least three coordinates")
    
    # For closed polygons, the last coordinate is typically a duplicate of the first
    # Exclude it from the average calculation (matches Flutter app behavior)
    coords_to_use = ring[:-1] if len(ring) > 1 and ring[0] == ring[-1] else ring
    
    sum_lon = sum(coord[0] for coord in coords_to_use)
    sum_lat = sum(coord[1] for coord in coords_to_use)
    count = len(coords_to_use)
    
    return sum_lon / count, sum_lat / count


def feature_point(feature_geometry: dict[str, t.Any]) -> tuple[float, float]:
    """Extract a single point from Point or Polygon geometry.
    
    For Point geometries, returns the coordinates directly.
    For Polygon geometries, returns the average of all vertices.
    """
    geom_type = feature_geometry["type"].lower()
    coords = feature_geometry["coordinates"]

    if geom_type == "point":
        return coords[0], coords[1]
    if geom_type == "polygon":
        # Use the exterior ring (first ring). Assume coordinates are closed.
        return _average_of_polygon(coords[0])

    raise NotImplementedError(f"Unsupported geometry type: {geom_type}. Only Point and Polygon are supported.")


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
        # Store pre-calculated coordinates for efficient app loading
        properties["lat"] = lat
        properties["lon"] = lon
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

    print("All files processed successfully!", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        raise SystemExit(130)
