#!/usr/bin/env bash
set -euxo pipefail

# ------------------------------------------------------
# Usage: ./generate-bdtopage-geojson.sh <output_dir> <shapefile_or_zip>
# ------------------------------------------------------

WORKDIR="$1"
INPUT_FILE="$2"
GEOJSON_DIR="$WORKDIR/geojson"


# Ensure output directories exist
mkdir -p "$GEOJSON_DIR"

# 1. Extract shapefile if ZIP
if [[ "$INPUT_FILE" == *.zip ]]; then
    ARCHIVE_NAME="${INPUT_FILE##*/}"
    ARCHIVE_BASE="${ARCHIVE_NAME%.[Zz][Ii][Pp]}"
    EXTRACT_DIR="$WORKDIR/shapefiles/$ARCHIVE_BASE"
    
    # Check if already extracted
    if [[ -d "$EXTRACT_DIR" ]] && find "$EXTRACT_DIR" -name "*.shp" | grep -q .; then
        echo "Shapefile already extracted in $EXTRACT_DIR, skipping extraction"
    else
        mkdir -p "$EXTRACT_DIR"
        echo "Extracting $INPUT_FILE to $EXTRACT_DIR"
        7z x -y "$INPUT_FILE" -o"$EXTRACT_DIR"
    fi

    # Find the extracted shapefile
    SHAPEFILE_PATH=$(find "$EXTRACT_DIR" -name "*.shp" | head -n 1)
else
    SHAPEFILE_PATH="$INPUT_FILE"
fi


# 2. Convert Shapefile to GeoJSON
OUTPUT_GEOJSON_FILE="$GEOJSON_DIR/$(basename "${SHAPEFILE_PATH%.*}").geojson"

# Convert with mapshaper and update property for projection change
mapshaper "$SHAPEFILE_PATH" \
    -proj wgs84 \
    -each 'ProjCoordO="WGS84 / EPSG:4326"' \
    -o format=geojson "$OUTPUT_GEOJSON_FILE"

echo "Converted $SHAPEFILE_PATH to $OUTPUT_GEOJSON_FILE with updated projection property"

