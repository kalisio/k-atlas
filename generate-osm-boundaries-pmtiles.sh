#/!bin/sh

echo "<> generating mbtiles"
tippecanoe -f -o osm-boundaries/osm-boundaries-all-zoom-levels.mbtiles --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed --no-tile-size-limit -Losm-boundaries:<(cat osm-boundaries/**/*.geojson)

echo "<> generating pmtiles"
pmtiles convert osm-boundaries/osm-boundaries-all-zoom-levels.mbtiles osm-boundaries/osm-boundaries.pmtiles
