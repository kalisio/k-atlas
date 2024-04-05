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
rm $ARCHIVE

