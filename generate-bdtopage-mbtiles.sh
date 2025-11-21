#!/usr/bin/env bash
set -euxo pipefail

# ------------------------------------------------------
# Usage: ./generate-bdtopage-mbtiles.sh <output_dir> <geojson_file>
# ------------------------------------------------------

OUTPUT_DIR="$1"
GEOJSON_FILE="$2"
MBTILES_LAYER_NAME_OVERRIDE="${3:-}"
MBTILES_DIR="$OUTPUT_DIR/mbtiles"

if [ -z "$OUTPUT_DIR" ] || [ -z "$GEOJSON_FILE" ]; then
    echo "Usage: $0 <output_dir> <geojson_file>"
    exit 1
fi

mkdir -p "$MBTILES_DIR"

# 3. Convert GeoJSON to MBTiles
MBTILES_OUTPUT_FILE="$MBTILES_DIR/$(basename "${GEOJSON_FILE%.*}").mbtiles"

if ! command -v tippecanoe >/dev/null 2>&1; then
    echo "tippecanoe is not installed or not in PATH" >&2
    exit 1
fi


if [ -n "$MBTILES_LAYER_NAME_OVERRIDE" ]; then
    tippecanoe \
        -o "$MBTILES_OUTPUT_FILE" \
        --force \
        -Z 0 -z 14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        -L "$MBTILES_LAYER_NAME_OVERRIDE":<(cat "$GEOJSON_FILE")
else
    tippecanoe \
        -o "$MBTILES_OUTPUT_FILE" \
        --force \
        -Z 0 -z 14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        "$GEOJSON_FILE"
fi



echo "Converted $GEOJSON_FILE to $MBTILES_OUTPUT_FILE"

