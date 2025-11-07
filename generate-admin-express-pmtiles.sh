#/!bin/sh

store='admin-express/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03/ADMIN-EXPRESS-COG-CARTO/1_DONNEES_LIVRAISON_2023-05-03/ADECOGC_3-2_SHP_WGS84G_FRA'

echo "<> generating mbtiles"
tippecanoe -f -o admin-express/admin-express-all-zoom-levels.mbtiles --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed --no-tile-size-limit -Ladmin-express:<(cat $store/*.geojson)

echo "<> generating pmtiles"
pmtiles convert admin-express/admin-express-all-zoom-levels.mbtiles admin-express/admin-express.pmtiles
