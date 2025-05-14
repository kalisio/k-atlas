#!/usr/bin/env bash
set -euxo pipefail

THIS_DIR=$(dirname "$(realpath "$0")")
TMPDIR="$THIS_DIR/tmp"
OUTDIR="$THIS_DIR/mbtiles"
MERGED="$OUTDIR/DFCI.mbtiles"

mkdir -p "$TMPDIR" "$OUTDIR"
rm -f "$TMPDIR"/*.geojson "$TMPDIR"/*.shp "$OUTDIR"/*.mbtiles

declare -A FILES=(
  ["DFCI-100km"]="https://www.data.gouv.fr/fr/datasets/r/5cf91d41-8e75-419c-9fdb-2fb52c690d5d"
  ["DFCI-20km"]="https://www.data.gouv.fr/fr/datasets/r/594d05e8-41fc-4a48-8b16-6eefd200d72b"
  ["DFCI-2km"]="https://www.data.gouv.fr/fr/datasets/r/ee0a9060-ddda-4e4f-b1ff-0b1555b59452"
)

# Zoom configuration
declare -A MINZOOM=(
  ["DFCI-100km"]=0
  ["DFCI-20km"]=6
  ["DFCI-2km"]=12
)
declare -A MAXZOOM=(
  ["DFCI-100km"]=5
  ["DFCI-20km"]=11
  ["DFCI-2km"]=15  
)

for NAME in "${!FILES[@]}"; do
  ZIPFILE="$TMPDIR/$NAME.7z"
  OUTSHAPE="$TMPDIR/$NAME"
  POLY_GEOJSON="$TMPDIR/$NAME.geojson"
  POINT_GEOJSON="$TMPDIR/${NAME}_centroids.geojson"
  MBTILES_FILE="$OUTDIR/$NAME.mbtiles"

  # Download and extract the shapefile
  if [ ! -f "$ZIPFILE" ]; then
    wget -O "$ZIPFILE" "${FILES[$NAME]}"
    7z x "$ZIPFILE" -o"$OUTSHAPE"
  fi

  SHP_FILE=$(find "$OUTSHAPE" -type f -name "*.shp" | head -n1)
  [[ -f "$SHP_FILE" ]] || { echo "No .shp file found in $OUTSHAPE"; exit 1; }

  # Convert the shapefile to GeoJSON
  mapshaper "$SHP_FILE" -quiet -proj wgs84 -o format=geojson force "$POLY_GEOJSON"

  # Generate centroids
  mapshaper "$SHP_FILE" -quiet -proj wgs84 -points centroid -o format=geojson force "$POINT_GEOJSON"


  # Convert to MBTiles
  tippecanoe -o "$MBTILES_FILE" "$POLY_GEOJSON" "$POINT_GEOJSON" \
    --force \
    --minimum-zoom="${MINZOOM[$NAME]}" \
    --maximum-zoom="${MAXZOOM[$NAME]}" \
    --layer="$NAME" \
    --drop-densest-as-needed --coalesce-densest-as-needed
done

# Merge MBTiles files
tile-join --force -o "$MERGED" "$OUTDIR"/*.mbtiles
