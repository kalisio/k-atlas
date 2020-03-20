#/!bin/bash

ARCHIVE=$1

# donwload the archive
lftp -u Admin_Express_ext,Dahnoh0eigheeFok ftp3.ign.fr -e "get $ARCHIVE; bye"

# extract the archive
7z x $ARCHIVE -oadmin-express

# find the shape files
SHAPES=`find admin-express -name *.shp`
for SHAPE in $SHAPES; do
  echo processing $SHAPE
  SHAPE_PATH=`dirname "${SHAPE}"`
  SHAPE_BASENAME=`basename "${SHAPE}"`
  JSON_BASENAME=${SHAPE_BASENAME//.shp/.geoson}
  echo converting $SHAPE_BASENAME in $JSON_BASENAME
  pushd "$SHAPE_PATH"
  mapshaper -i $SHAPE_BASENAME -o format=geojson precision=0.000001 $JSON_BASENAME
  popd
done
