#/!bin/sh

echo "<> generating boundaries mbtiles"
tippecanoe -f -o osm-boundaries/2/boundaries.mbtiles -Z2 -z5 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel2:<(cat osm-boundaries/2/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/3/boundaries.mbtiles -Z2 -z6 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel3:<(cat osm-boundaries/3/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/4/boundaries.mbtiles -Z4 -z8 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel4:<(cat osm-boundaries/4/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/5/boundaries.mbtiles -Z5 -z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel5:<(cat osm-boundaries/5/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/6/boundaries.mbtiles -Z6 -z11 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel6:<(cat osm-boundaries/6/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/7/boundaries.mbtiles -Z7 -z12 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel7:<(cat osm-boundaries/7/*-boundaries.geojson)
tippecanoe -f -o osm-boundaries/8/boundaries.mbtiles -Z9 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Llevel8:<(cat osm-boundaries/8/*-boundaries.geojson)

echo "<> generating toponyms mbtiles"
tippecanoe -f -o osm-boundaries/2/toponyms.mbtiles -Z2 -z5 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel2toponyms:<(cat osm-boundaries/2/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/3/toponyms.mbtiles -Z2 -z6 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel3toponyms:<(cat osm-boundaries/3/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/4/toponyms.mbtiles -Z4 -z8 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel4toponyms:<(cat osm-boundaries/4/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/5/toponyms.mbtiles -Z5 -z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel5toponyms:<(cat osm-boundaries/5/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/6/toponyms.mbtiles -Z6 -z11 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel6toponyms:<(cat osm-boundaries/6/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/7/toponyms.mbtiles -Z7 -z12 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel7toponyms:<(cat osm-boundaries/7/*-toponyms.geojson)
tippecanoe -f -o osm-boundaries/8/toponyms.mbtiles -Z9 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Llevel8toponyms:<(cat osm-boundaries/8/*-toponyms.geojson)

echo "<> merging toponyms mbtiles"
tile-join -f -o osm-boundaries/osm-boundaries-toponyms.mbtiles \
  osm-boundaries/2/toponyms.mbtiles \
  osm-boundaries/3/toponyms.mbtiles \
  osm-boundaries/4/toponyms.mbtiles \
  osm-boundaries/5/toponyms.mbtiles \
  osm-boundaries/6/toponyms.mbtiles \
  osm-boundaries/7/toponyms.mbtiles \
  osm-boundaries/8/toponyms.mbtiles

echo "<> merging boundaries mbtiles"
tile-join -f -o osm-boundaries/osm-boundaries-polygons.mbtiles \
  osm-boundaries/2/boundaries.mbtiles \
  osm-boundaries/3/boundaries.mbtiles \
  osm-boundaries/4/boundaries.mbtiles \
  osm-boundaries/5/boundaries.mbtiles \
  osm-boundaries/6/boundaries.mbtiles \
  osm-boundaries/7/boundaries.mbtiles \
  osm-boundaries/8/boundaries.mbtiles

echo "<> merging all mbtiles"
tile-join -f -o osm-boundaries/osm-boundaries.mbtiles osm-boundaries/osm-boundaries-polygons.mbtiles osm-boundaries/osm-boundaries-toponyms.mbtiles