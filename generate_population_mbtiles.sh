#!/usr/bin/env bash
set -euo pipefail

FIL200="https://www.insee.fr/fr/statistiques/fichier/8735162/Filosofi2021_carreaux_200m_shp.zip"
FIL1KM="https://www.insee.fr/fr/statistiques/fichier/8735171/Filosofi2021_carreaux_1km_shp.zip"

SHAPEFILE_DIR_1KM=${1:-Filosofi2021_carreaux_1km_shp}
SHAPEFILE_DIR_200M=${2:-Filosofi2021_carreaux_200m_shp}
OUTPUT_MBTILES=${3:-population_2021.mbtiles}

command -v wget >/dev/null || { echo "wget manquant" >&2; exit 1; }
command -v unzip >/dev/null || { echo "unzip manquant" >&2; exit 1; }
command -v mapshaper >/dev/null || { echo "mapshaper manquant" >&2; exit 1; }
command -v tippecanoe >/dev/null || { echo "tippecanoe manquant" >&2; exit 1; }
command -v tile-join >/dev/null || { echo "tile-join manquant" >&2; exit 1; }

download_and_unzip() {
  local url="$1"
  local zip_name="$2"
  local target_dir="$3"

  if [[ -d "$target_dir" ]]; then
    echo "Dossier déjà présent : $target_dir"
    return 0
  fi

  echo "Téléchargement de $zip_name..."
  wget -qO "$zip_name" "$url"
  echo "Décompression de $zip_name..."
  unzip -q "$zip_name"
  rm -f "$zip_name"
}

download_and_unzip "$FIL200" "Filosofi2021_carreaux_200m_shp.zip" "$SHAPEFILE_DIR_200M"
download_and_unzip "$FIL1KM" "Filosofi2021_carreaux_1km_shp.zip" "$SHAPEFILE_DIR_1KM"

process_shapefile_dir() {
  local dir="$1"
  local grid_size="$2"
  local output_geojson="$3"
  local output_mbtiles="$4"
  local layer_name="$5"

  [[ -d "$dir" ]] || { echo "Répertoire $dir manquant" >&2; return 1; }

  local shp_path
  shp_path=$(find "$dir" -maxdepth 1 -name "*.shp" | head -n1)
  [[ -n "$shp_path" ]] || { echo "Pas de shp dans $dir" >&2; return 1; }

  echo "Traitement $grid_size : $shp_path"

  if [[ "$grid_size" == "1km" ]]; then
    mapshaper "$shp_path" \
      -proj EPSG:4326 \
      -rename-fields Ind=ind \
      -o "$output_geojson" format=geojson

    tippecanoe -z11 -Z7 -P --force --maximum-tile-bytes=3000000 \
      --coalesce-densest-as-needed --no-tile-size-limit \
      --no-feature-limit --extend-zooms-if-still-dropping \
      -l "$layer_name" -o "$output_mbtiles" "$output_geojson"
  else
    mapshaper-xl 16gb "$shp_path" \
      -proj EPSG:4326 \
      -rename-fields Ind=ind \
      -o "$output_geojson" format=geojson

    tippecanoe -z15 -Z12 -P --coalesce-densest-as-needed --force \
      -l "$layer_name" -o "$output_mbtiles" "$output_geojson"
  fi

  rm -f "$output_geojson"
  echo "MBTiles $grid_size généré : $output_mbtiles"
}

echo "=== Traitement 1KM ==="
process_shapefile_dir "$SHAPEFILE_DIR_1KM/france_metro" "1km" "tmp_1km_metro.geojson" "1km_metro.mbtiles" "densite_insee_1000m_4326"
process_shapefile_dir "$SHAPEFILE_DIR_1KM/la_reunion" "1km" "tmp_1km_reunion.geojson" "1km_reunion.mbtiles" "densite_insee_1000m_4326"
process_shapefile_dir "$SHAPEFILE_DIR_1KM/martinique" "1km" "tmp_1km_martinique.geojson" "1km_martinique.mbtiles" "densite_insee_1000m_4326"

echo "Fusion 1KM → 1km_complet.mbtiles"
tile-join --force --no-tile-size-limit -o "1km_complet.mbtiles" \
  1km_metro.mbtiles 1km_reunion.mbtiles 1km_martinique.mbtiles

echo "=== Traitement 200M ==="
process_shapefile_dir "$SHAPEFILE_DIR_200M/france_metro" "200m" "tmp_200m_metro.geojson" "200m_metro.mbtiles" "densite_insee_200m_4326"
process_shapefile_dir "$SHAPEFILE_DIR_200M/la_reunion" "200m" "tmp_200m_reunion.geojson" "200m_reunion.mbtiles" "densite_insee_200m_4326"
process_shapefile_dir "$SHAPEFILE_DIR_200M/martinique" "200m" "tmp_200m_martinique.geojson" "200m_martinique.mbtiles" "densite_insee_200m_4326"

echo "Fusion 200M → 200m_complet.mbtiles"
tile-join --force --no-tile-size-limit -o "200m_complet.mbtiles" \
  200m_metro.mbtiles 200m_reunion.mbtiles 200m_martinique.mbtiles

echo "Fusion finale 1KM + 200M → $OUTPUT_MBTILES"
tile-join --force --no-tile-size-limit -o "$OUTPUT_MBTILES" \
  1km_complet.mbtiles 200m_complet.mbtiles

rm -f 1km_*.mbtiles 200m_*.mbtiles 1km_complet.mbtiles 200m_complet.mbtiles

echo "✅ MBTiles complet généré : $OUTPUT_MBTILES"