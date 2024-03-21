#/!bin/sh

# Set file basename
FILE_PREFIX=planet

echo "<> generating boundaries mbtiles"
tippecanoe -f -o osm-boundaries/2/${FILE_PREFIX}_2_boundaries.mbtiles -Z2 -z5 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel2:<(cat osm-boundaries/2/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/3/${FILE_PREFIX}_3_boundaries.mbtiles -Z2 -z6 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel3:<(cat osm-boundaries/3/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/4/${FILE_PREFIX}_4_boundaries.mbtiles -Z4 -z8 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel4:<(cat osm-boundaries/4/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/5/${FILE_PREFIX}_5_boundaries.mbtiles -Z5 -z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel5:<(cat osm-boundaries/5/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/6/${FILE_PREFIX}_6_boundaries.mbtiles -Z6 -z11 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel6:<(cat osm-boundaries/6/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/7/${FILE_PREFIX}_7_boundaries.mbtiles -Z7 -z12 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel7:<(cat osm-boundaries/7/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/8/${FILE_PREFIX}_8_boundaries.mbtiles -Z9 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel8:<(cat osm-boundaries/8/*-boundaries.geojson)

echo "<> generating toponymes mbtiles"
tippecanoe -f -o osm-boundaries/2/${FILE_PREFIX}_2_toponyms.mbtiles -Z2 -z5 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel2toponyms:<(cat osm-boundaries/2/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/3/${FILE_PREFIX}_3_toponyms.mbtiles -Z2 -z6 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel3toponyms:<(cat osm-boundaries/3/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/4/${FILE_PREFIX}_4_toponyms.mbtiles -Z4 -z8 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel4toponyms:<(cat osm-boundaries/4/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/5/${FILE_PREFIX}_5_toponyms.mbtiles -Z5 -z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel5toponyms:<(cat osm-boundaries/5/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/6/${FILE_PREFIX}_6_toponyms.mbtiles -Z6 -z11 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel6toponyms:<(cat osm-boundaries/6/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/7/${FILE_PREFIX}_7_toponyms.mbtiles -Z7 -z12 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel7toponyms:<(cat osm-boundaries/7/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/8/${FILE_PREFIX}_8_toponyms.mbtiles -Z9 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel8toponyms:<(cat osm-boundaries/8/*-toponyms.geojson)

echo "<> merging toponyms mbtiles"
tile-join -f -o osm-boundaries/osm-boundaries-toponyms.mbtiles \
  osm-boundaries/2/${FILE_PREFIX}_2_toponyms.mbtiles \
  osm-boundaries/3/${FILE_PREFIX}_3_toponyms.mbtiles \
  osm-boundaries/4/${FILE_PREFIX}_4_toponyms.mbtiles \
  osm-boundaries/5/${FILE_PREFIX}_5_toponyms.mbtiles \
  osm-boundaries/6/${FILE_PREFIX}_6_toponyms.mbtiles \
  osm-boundaries/7/${FILE_PREFIX}_7_toponyms.mbtiles \
  osm-boundaries/8/${FILE_PREFIX}_8_toponyms.mbtiles

echo "<> merging boundaries mbtiles"
tile-join -f -o osm-boundaries/osm-boundaries.mbtiles \
  osm-boundaries/2/${FILE_PREFIX}_2_boundaries.mbtiles \
  osm-boundaries/3/${FILE_PREFIX}_3_boundaries.mbtiles \
  osm-boundaries/4/${FILE_PREFIX}_4_boundaries.mbtiles \
  osm-boundaries/5/${FILE_PREFIX}_5_boundaries.mbtiles \
  osm-boundaries/6/${FILE_PREFIX}_6_boundaries.mbtiles \
  osm-boundaries/7/${FILE_PREFIX}_7_boundaries.mbtiles \
  osm-boundaries/8/${FILE_PREFIX}_8_boundaries.mbtiles