#!/usr/bin/env bash
set -euxo pipefail

ADMIN_EXPRESS_DIR="$1"
POLYNESIA_DIR="$2"

ADMIN_EXPRESS_REGION=$(find "$ADMIN_EXPRESS_DIR" -name "REGION.shp")
ADMIN_EXPRESS_DIRNAME=$(dirname "$ADMIN_EXPRESS_REGION")

# Generate PAYS layer using mapshaper
mapshaper "$ADMIN_EXPRESS_REGION" \
    -dissolve copy-fields="" \
    -o "$ADMIN_EXPRESS_DIRNAME/PAYS_tmp.shp"

# Merge with polynesia since it's not in REGION layer
mapshaper -i "$ADMIN_EXPRESS_DIRNAME/PAYS_tmp.shp" "$POLYNESIA_DIR/DEPARTEMENT.shp" combine-files \
    -drop 'fields=*' \
    -merge-layers \
    -dissolve copy-fields="" \
    -simplify "50%" keep-shapes \
    -o "$ADMIN_EXPRESS_DIRNAME/PAYS.shp"

rm "$ADMIN_EXPRESS_DIRNAME/PAYS_tmp.shp"
