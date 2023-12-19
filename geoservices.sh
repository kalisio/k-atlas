#/!bin/sh

ARCHIVE=$1
HOST=$2
USER=$3
PASS=$4

# donwload the archive
# note: wget stuck in passive mode and curl is really slow 
echo "<> downloading $ARCHIVE from $HOST" 
lftp -u $USER,$PASS $HOST -e "get $ARCHIVE; bye"

# extract the archive
echo "<> extracting $ARCHIVE"
rm -fr dataset
7z x $ARCHIVE -odataset

# find the shape files
SHAPES=`find dataset -name *.shp`

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
  mapshaper -i $SHAPE_BASENAME -o format=geojson precision=0.000001 $JSON_BASENAME
  cd $WORKDIR
done

