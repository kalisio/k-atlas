#!/usr/bin/env bash
set -euxo pipefail

POLYNESIA_DIR="$1"
ADMIN_EXPRESS_DIR="$2"
TMPDIR="tmp/$1"

mkdir -p "$TMPDIR" "$POLYNESIA_DIR"

# Données issues de https://www.data.gouv.fr/fr/datasets/limites-geographiques-administratives/
# Code INSEE issus de https://www.tefenua.data.gov.pf/maps/6e392df616c949309eda19656450562a/about (couche ISPF_Codes_INSEE)

wget -O "$TMPDIR/shapefiles.zip" "https://www.data.gouv.fr/fr/datasets/r/211bb006-aba5-475f-a40b-53b42ae765a2"
wget -O "$TMPDIR/ISPF_Codes_INSEE.csv" "https://hub.arcgis.com/api/v3/datasets/6e392df616c949309eda19656450562a_6/downloads/data?format=csv&spatialRefId=3857&where=1%3D1"

7z x -y "$TMPDIR/shapefiles.zip" -o"$TMPDIR/shapefiles"

# 1. Patch some commune names that don't match the one in ISPF_Codes_INSEE
# 2. Merge with INSEE code
# 3. Rename properties to match admin-express
# 4. Add INSEE_DEP to match admin-express
# 5. Remove original properties
# 6. Reproject to WGS84
mapshaper "$TMPDIR/shapefiles/Com.shp" \
    -each 'Commune = "Bora-Bora"' where='Commune == "Bora Bora"' \
    -each 'Commune = "Faaa"' where="Commune == \"Faa'a\"" \
    -each 'Commune = "Fatu-Hiva"' where='Commune == "Fatu Hiva"' \
    -each 'Commune = "Hiva-Oa"' where='Commune == "Hiva Oa"' \
    -each 'Commune = "Nuku-Hiva"' where='Commune == "Nuku Hiva"' \
    -each 'Commune = "Ua-Huka"' where='Commune == "Ua Huka"' \
    -each 'Commune = "Ua-Pou"' where='Commune == "Ua Pou"' \
    -join "$TMPDIR/ISPF_Codes_INSEE.csv" keys=Commune,Communes fields=Code_INSEE_complet string-fields=Code_INSEE_complet \
    -rename-fields INSEE_COM=Code_INSEE_complet,NOM=Commune,POPULATION=Indivds \
    -each 'INSEE_DEP = "987", NOM_M = NOM.toUpperCase()' \
    -filter-fields INSEE_COM,INSEE_DEP,NOM,NOM_M,POPULATION \
    -proj wgs84 \
    -simplify "90%" keep-shapes \
    -o "$POLYNESIA_DIR/COMMUNE.shp"

# Generate departement
# Simplify geometry in the process
mapshaper "$POLYNESIA_DIR/COMMUNE.shp" \
    -dissolve copy-fields="" calc='NOM = "Polynésie française", NOM_M = "POLYNÉSIE FRANÇAISE", INSEE_DEP = "987"' \
    -simplify "50%" keep-shapes \
    -o "$POLYNESIA_DIR/DEPARTEMENT.shp"

# Merge with admin-express
for LAYER in COMMUNE DEPARTEMENT; do
    ADMIN_EXPRESS_FILE=$(find "$ADMIN_EXPRESS_DIR" -name "$LAYER.shp")
    ADMIN_EXPRESS_DIRNAME=$(dirname "$ADMIN_EXPRESS_FILE")

    for EXT in cpg dbf prj shp shx; do
        mv "$ADMIN_EXPRESS_DIRNAME/$LAYER.$EXT" "$ADMIN_EXPRESS_DIRNAME/${LAYER}_src.$EXT"
    done

    mapshaper -i "$ADMIN_EXPRESS_DIRNAME/${LAYER}_src.shp" "$POLYNESIA_DIR/$LAYER.shp" combine-files -merge-layers force -o "$ADMIN_EXPRESS_DIRNAME/$LAYER.shp"

    for EXT in cpg dbf prj shp shx; do
        rm "$ADMIN_EXPRESS_DIRNAME/${LAYER}_src.$EXT"
    done
done
