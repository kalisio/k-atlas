#!/usr/bin/env bash
set -euxo pipefail

WORKDIR=$1

gen_polynesia_geojson() {
    local OUTDIR="$1/polynesia"
    local TMPDIR="$1/tmp/polynesia"

    mkdir -p "$TMPDIR" "$OUTDIR"

    # Données issues de https://www.data.gouv.fr/fr/datasets/limites-geographiques-administratives/
    # Code INSEE issus de https://www.tefenua.data.gov.pf/maps/6e392df616c949309eda19656450562a/about (couche ISPF_Codes_INSEE)

    wget -O "$TMPDIR/shapefiles.zip" "https://www.data.gouv.fr/fr/datasets/r/211bb006-aba5-475f-a40b-53b42ae765a2"
    wget -O "$TMPDIR/ISPF_Codes_INSEE.csv" "https://hub.arcgis.com/api/v3/datasets/6e392df616c949309eda19656450562a_6/downloads/data?format=csv&spatialRefId=3857&where=1%3D1"

    7z x "$TMPDIR/shapefiles.zip" -o"$TMPDIR/shapefiles"

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
        -o "$OUTDIR/COMMUNE.shp"
    # Generate communes toponymes (= points a center of mass for each feature)
    mapshaper "$OUTDIR/COMMUNE.shp" -points centroid -o "$OUTDIR/COMMUNE-toponyms.geojson"

    # Generate departement
    mapshaper "$OUTDIR/COMMUNE.shp" -dissolve copy-fields="" calc='NOM = "Polynésie française", NOM_M = "POLYNÉSIE FRANÇAISE", INSEE_DEP = "987"' -o "$OUTDIR/DEPARTEMENT.shp"
    # Generate departements toponymes (= points a center of mass for each feature)
    mapshaper "$OUTDIR/DEPARTEMENT.shp" -points centroid -o "$OUTDIR/DEPARTEMENT-toponyms.geojson"
}

gen_admin_express_geojson() {
    local OUTDIR="$1/admin_express"
    local TMPDIR="$1/tmp/admin_express"

    local ADMIN_EXPR_URL="https://data.geopf.fr/telechargement/download/ADMIN-EXPRESS-COG-CARTO/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03.7z"
    local ARCHIVE
    ARCHIVE=$(basename "$ADMIN_EXPR_URL")

    mkdir -p "$TMPDIR" "$OUTDIR"

    wget -O "$TMPDIR/$ARCHIVE" "$ADMIN_EXPR_URL"

    7z x "$TMPDIR/$ARCHIVE" -o"$TMPDIR/extract"

    for LAYER in ARRONDISSEMENT CANTON COLLECTIVITE_TERRITORIALE COMMUNE DEPARTEMENT EPCI REGION; do
        local LAYER_FILE
        LAYER_FILE=$(find "$TMPDIR/extract" -name "$LAYER.shp")

        # Generate communes toponymes (= points a center of mass for each feature)
        mapshaper "$LAYER_FILE" -points centroid -o "$OUTDIR/$LAYER-toponyms.geojson"
    done
}

gen_mbtiles() {
    local OUTDIR="$1/mbtiles"
    local TMPDIR="$1/tmp/mbtiles"

    mkdir -p "$TMPDIR" "$OUTDIR"

    # Merge layers
    for LAYER in COMMUNE DEPARTEMENT; do
        local LAYER_FILE
        LAYER_FILE=$(find "$1/tmp/admin_express/extract" -name "$LAYER.shp")

        mapshaper -i "$LAYER_FILE" "$1/polynesia/$LAYER.shp" combine-files -merge-layers force -o "$OUTDIR/$LAYER.geojson"
        mapshaper -i "$1/admin_express/$LAYER-toponyms.geojson" "$1/polynesia/$LAYER-toponyms.geojson" combine-files -merge-layers force -o "$OUTDIR/$LAYER-toponyms.geojson"
    done

    # Convert to geojson
    for LAYER in ARRONDISSEMENT CANTON COLLECTIVITE_TERRITORIALE EPCI REGION; do
        local LAYER_FILE
        LAYER_FILE=$(find "$1/tmp/admin_express/extract" -name "$LAYER.shp")

        mapshaper "$LAYER_FILE" -o "$OUTDIR/$LAYER.geojson"
    done

    # Produce mbtiles
    tippecanoe -f -o "$OUTDIR/ARRONDISSEMENT.mbtiles" -Z12 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Larrondissement:<(cat "$OUTDIR/ARRONDISSEMENT.geojson")
    tippecanoe -f -o "$OUTDIR/COMMUNE.mbtiles" -Z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lcommune:<(cat "$OUTDIR/COMMUNE.geojson")
    tippecanoe -f -o "$OUTDIR/DEPARTEMENT.mbtiles" -Z7 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Ldepartement:<(cat "$OUTDIR/DEPARTEMENT.geojson")
    tippecanoe -f -o "$OUTDIR/CANTON.mbtiles" -Z7 -z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lcanton:<(cat "$OUTDIR/CANTON.geojson")
    tippecanoe -f -o "$OUTDIR/EPCI.mbtiles" -Z6 -z9 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lecpi:<(cat "$OUTDIR/EPCI.geojson")
    tippecanoe -f -o "$OUTDIR/COLLECTIVITE_TERRITORIALE.mbtiles" -Z5 -z8 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lcollectivite-territoriale:<(cat "$OUTDIR/COLLECTIVITE_TERRITORIALE.geojson")
    tippecanoe -f -o "$OUTDIR/REGION.mbtiles" -Z3 -z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lregion:<(cat "$OUTDIR/REGION.geojson")

    tippecanoe -f -o "$OUTDIR/ARRONDISSEMENT-toponyms.mbtiles" -Z12 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Larrondissement_toponyme:<(cat "$1/admin_express/ARRONDISSEMENT-toponyms.geojson")
    tippecanoe -f -o "$OUTDIR/COMMUNE-toponyms.mbtiles" -Z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lcommune_toponyme:<(cat "$OUTDIR/COMMUNE-toponyms.geojson")
    tippecanoe -f -o "$OUTDIR/DEPARTEMENT-toponyms.mbtiles" -Z7 -z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Ldepartement_toponyme:<(cat "$OUTDIR/DEPARTEMENT-toponyms.geojson")
    tippecanoe -f -o "$OUTDIR/CANTON-toponyms.mbtiles" -Z7 -z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lcanton_toponyme:<(cat "$1/admin_express/CANTON-toponyms.geojson")
    tippecanoe -f -o "$OUTDIR/EPCI-toponyms.mbtiles" -Z6 -z9 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lepci_toponyme:<(cat "$1/admin_express/EPCI-toponyms.geojson")
    tippecanoe -f -o "$OUTDIR/COLLECTIVITE_TERRITORIALE-toponyms.mbtiles" -Z5 -z8 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lcollectivite-territoriale_toponyme:<(cat "$1/admin_express/COLLECTIVITE_TERRITORIALE-toponyms.geojson")
    tippecanoe -f -o "$OUTDIR/REGION-toponyms.mbtiles" -Z5 -z8 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lregion_toponyme:<(cat "$1/admin_express/REGION-toponyms.geojson")

    tile-join -f -o "$1/admin-express.mbtiles" \
        "$OUTDIR/ARRONDISSEMENT.mbtiles" \
        "$OUTDIR/ARRONDISSEMENT-toponyms.mbtiles" \
        "$OUTDIR/CANTON.mbtiles" \
        "$OUTDIR/CANTON-toponyms.mbtiles" \
        "$OUTDIR/COLLECTIVITE_TERRITORIALE.mbtiles" \
        "$OUTDIR/COLLECTIVITE_TERRITORIALE-toponyms.mbtiles" \
        "$OUTDIR/COMMUNE.mbtiles" \
        "$OUTDIR/COMMUNE-toponyms.mbtiles" \
        "$OUTDIR/DEPARTEMENT.mbtiles" \
        "$OUTDIR/DEPARTEMENT-toponyms.mbtiles" \
        "$OUTDIR/EPCI.mbtiles" \
        "$OUTDIR/EPCI-toponyms.mbtiles" \
        "$OUTDIR/REGION.mbtiles" \
        "$OUTDIR/REGION-toponyms.mbtiles"
}

gen_polynesia_geojson "$WORKDIR"
gen_admin_express_geojson "$WORKDIR"
gen_mbtiles "$WORKDIR"
