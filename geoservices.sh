#!/usr/bin/env bash
set -euo pipefail

URL=$1
OUTPUT_DIRECTORY=$2

# donwload the archive
echo "<> downloading from $URL"
wget $URL

ARCHIVE=`basename $URL`

# extract the archive
echo "<> extracting $ARCHIVE"
rm -fr $OUTPUT_DIRECTORY
7z x $ARCHIVE -o$OUTPUT_DIRECTORY

# find the shape files
SHAPES=`find $OUTPUT_DIRECTORY -name *.shp`

# iterate though the files and convert them using mapshaper
echo "<> converting files"
WORKDIR=`pwd`
for SHAPE in $SHAPES; do
  echo processing $SHAPE
  SHAPE_PATH=`dirname "${SHAPE}"`
  SHAPE_BASENAME=`basename "${SHAPE}"`
  JSON_BASENAME=`echo $SHAPE_BASENAME | sed -e 's/.shp/.geojson/g'` # cannot use variable substitution as we are running in shell not bash
  echo converting $SHAPE_BASENAME in $JSON_BASENAME
  cd $SHAPE_PATH
  mapshaper -i $SHAPE_BASENAME -proj wgs84 -o format=geojson precision=0.000001 $JSON_BASENAME
  cd $WORKDIR
done

