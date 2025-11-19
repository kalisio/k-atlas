#!/usr/bin/env bash
set -euxo pipefail

URL=${1:-https://services.sandre.eaufrance.fr/telechargement/geo/ETH/BDTopage/2024/BD_Topage_FXX_2024-shp.zip}
TOPAGE_DIR="$2"
mkdir -p  "$TOPAGE_DIR"

# 1. Download the complete Topage shapefiles archive with all the layers archived
if [ ! -f "$TOPAGE_DIR/shapefiles.zip" ]; then
    wget -q -O "$TOPAGE_DIR/shapefiles.zip" "$URL"
fi

# 2. Extract the archive
if [ ! -d "$TOPAGE_DIR/archives" ]; then
    mkdir -p "$TOPAGE_DIR/archives"
    7z x -y "$TOPAGE_DIR/shapefiles.zip" -o"$TOPAGE_DIR/archives"
fi

exit 0

