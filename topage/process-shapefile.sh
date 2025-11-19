#!/usr/bin/env bash
set -euxo pipefail

# ------------------------------------------------------
# Usage: ./process-shapefile.sh <output_dir> <shapefile_or_zip>
# ------------------------------------------------------

TOPAGE_DIR="$1"
INPUT_FILE="$2"
GEOJSON_DIR="$TOPAGE_DIR/geojson"
MBTILES_DIR="$TOPAGE_DIR/mbtiles"

# Ensure output directories exist
mkdir -p "$GEOJSON_DIR" "$MBTILES_DIR"

# 1. Extract shapefile if ZIP
if [[ "$INPUT_FILE" == *.zip ]]; then
    ARCHIVE_NAME="${INPUT_FILE##*/}"
    ARCHIVE_BASE="${ARCHIVE_NAME%.[Zz][Ii][Pp]}"
    EXTRACT_DIR="$TOPAGE_DIR/shapefiles/$ARCHIVE_BASE"
    
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

# 3. Convert GeoJSON to MBTiles
MBTILES_OUTPUT_FILE="$MBTILES_DIR/$(basename "${SHAPEFILE_PATH%.*}").mbtiles"

tippecanoe \
    -o "$MBTILES_OUTPUT_FILE" \
    --force \
    -Z 0 -z 14 \
    --drop-densest-as-needed \
    --extend-zooms-if-still-dropping \
    "$OUTPUT_GEOJSON_FILE"

echo "Converted $OUTPUT_GEOJSON_FILE to $MBTILES_OUTPUT_FILE"

