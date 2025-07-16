#/!bin/sh

echo "<> generating boundaries gpkg"
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/2/boundaries.gpkg -nln level2 osm-boundaries/2/*-boundaries.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/3/boundaries.gpkg -nln level3 osm-boundaries/3/*-boundaries.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/4/boundaries.gpkg -nln level4 osm-boundaries/4/*-boundaries.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/5/boundaries.gpkg -nln level5 osm-boundaries/5/*-boundaries.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/6/boundaries.gpkg -nln level6 osm-boundaries/6/*-boundaries.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/7/boundaries.gpkg -nln level7 osm-boundaries/7/*-boundaries.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/8/boundaries.gpkg -nln level8 osm-boundaries/8/*-boundaries.geojson

echo "<> generating toponyms gpkg"
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/2/toponyms.gpkg -nln level2 osm-boundaries/2/*-toponyms.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/3/toponyms.gpkg -nln level3 osm-boundaries/3/*-toponyms.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/4/toponyms.gpkg -nln level4 osm-boundaries/4/*-toponyms.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/5/toponyms.gpkg -nln level5 osm-boundaries/5/*-toponyms.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/6/toponyms.gpkg -nln level6 osm-boundaries/6/*-toponyms.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/7/toponyms.gpkg -nln level7 osm-boundaries/7/*-toponyms.geojson
ogrmerge -f GPKG -single -overwrite_ds -o osm-boundaries/8/toponyms.gpkg -nln level8 osm-boundaries/8/*-toponyms.geojson

echo "<> merging toponyms gpkg"
ogrmerge -f GPKG -overwrite_ds -o osm-boundaries/osm-boundaries-toponyms.gpkg -nln {LAYER_NAME} \
  osm-boundaries/2/toponyms.gpkg \
  osm-boundaries/3/toponyms.gpkg \
  osm-boundaries/4/toponyms.gpkg \
  osm-boundaries/5/toponyms.gpkg \
  osm-boundaries/6/toponyms.gpkg \
  osm-boundaries/7/toponyms.gpkg \
  osm-boundaries/8/toponyms.gpkg

echo "<> merging boundaries gpkg"
ogrmerge -f GPKG -overwrite_ds -o osm-boundaries/osm-boundaries-polygons.gpkg -nln {LAYER_NAME} \
  osm-boundaries/2/boundaries.gpkg \
  osm-boundaries/3/boundaries.gpkg \
  osm-boundaries/4/boundaries.gpkg \
  osm-boundaries/5/boundaries.gpkg \
  osm-boundaries/6/boundaries.gpkg \
  osm-boundaries/7/boundaries.gpkg \
  osm-boundaries/8/boundaries.gpkg

echo "<> merging all gpkg"
ogrmerge -f GPKG -overwrite_ds -o osm-boundaries/osm-boundaries.gpkg -nln polygons-{LAYER_NAME} osm-boundaries/osm-boundaries-polygons.gpkg
ogrmerge -update -o osm-boundaries/osm-boundaries.gpkg -nln toponyms-{LAYER_NAME} osm-boundaries/osm-boundaries-toponyms.gpkg

