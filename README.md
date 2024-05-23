# k-atlas

[![Latest Release](https://img.shields.io/github/v/tag/kalisio/k-atlas?sort=semver&label=latest)](https://github.com/kalisio/k-atlas/releases)
[![CI](https://github.com/kalisio/k-atlas/actions/workflows/main.yaml/badge.svg)](https://github.com/kalisio/k-atlas/actions/workflows/main.yaml)
[![Code Climate](https://codeclimate.com/github/kalisio/k-atlas/badges/gpa.svg)](https://codeclimate.com/github/kalisio/k-atlas)
[![Test Coverage](https://codeclimate.com/github/kalisio/k-atlas/badges/coverage.svg)](https://codeclimate.com/github/kalisio/k-atlas/coverage)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[Krawler](https://kalisio.github.io/krawler/) based jobs to scrape various data related to administrative entities.

## OSM boundaries

This job relies on:
- [osmium](https://osmcode.org/osmium-tool) to extract administrative boundaries at different level from OSM pbf files,
- [ogr2ogr](https://gdal.org/programs/ogr2ogr.html) to generate sequential GeoJson files to handle large datasets,
- [mapshaper](https://github.com/mbloch/mapshaper) to simplify complex geometries,
- [tippecanoe](https://github.com/felt/tippecanoe) to generate MBTiles,
- [turfjs](https://turfjs.org/) to compute the position of toponyms.

> [!IMPORTANT]  
> osmium, ogr, mapshaper and tippecanoe command-line tools must be installed on your system. 

To setup the regions to process, you must export the environment variables `REGIONS` with the [GeoFabrik](https://download.geofabrik.de/) regions. For instance:
```bash
export REGIONS="europe/france;europe/albania"
```

If you'd like to simplify geometries you can setup the simplification tolerance and algorithm:
```bash
export SIMPLIFICATION_TOLERANCE=500 # defaults to 128
export SIMPLIFICATION_ALGORITHM=visvalingam # defaults to 'db'
```

> Note
>
> The given simplification tolerance will be scaled according to administrative level using this formula: `tolerance at level N = tolerance / 2^(N-2)`

For testing purpose you can also limit the processed administrative levels using the `MIN_LEVEL/MAX_LEVEL` environment variables.

### Planet generation

To generate the whole planet use continent extracts like this first to launch the `osm-boundaries` job from level 3 to 8:
```bash
export REGIONS="africa;asia;australia-oceania;central-america;europe;north-america;south-america"
```

As large files are generated for e.g. Europe you might have to increase the default NodeJS memory limit:
```bash
export NODE_OPTIONS=--max-old-space-size=8192
```

Then, launch the `osm-planet-boundaries` job for level 2, which uses a planet extract, and planet MBTiles generation. Indeed, country-level (i.e. administrative level 2) requires a whole planet file to avoid missing relation between continental and islands areas.

Last but not least, launch the `generate-osm-boundaries-mbtiles.sh` script to generate a MBTils file from GeoJson files produced by the job.

To avoid generating data multiple times you can easily dump/restore it from/to MongoDB databases:
```bash
mongodump --host=localhost --port=27017 --username=user --password=password --db=atlas --collection=osm-boundaries --gzip --out dump
mongorestore --db=atlas --gzip --host=mongodb.example.net --port=27018 --username=user --password=password dump/atlas
```

## Admin-Express

This job relies on archive shape files from IGN and the [mapshaper](https://github.com/mbloch/mapshaper) and [7z](https://www.7-zip.org/download.html) tools.

https://geoservices.ign.fr/documentation/diffusion/telechargement-donnees-libres.html#admin-express

## BDPR

This job relies on archive shape files from IGN and the [mapshaper](https://github.com/mbloch/mapshaper) and [7z](https://www.7-zip.org/download.html) tools.

https://geoservices.ign.fr/documentation/diffusion/telechargement-donnees-libres.html#bdpr

## Development

To debug you can run this command from a local krawler install `node --inspect . ../k-atlas/jobfile-bdpr.js`.

To run it on the infrastructure we use Docker images based on the provided Docker files, if you'd like to test it manually you can clone the repo then do:
```
docker build --build-arg KRAWLER_TAG=latest -f dockerfile.bdpr -t k-atlas/bdpr-latest .
docker run --name bdpr --network=host --rm -e S3_ACCESS_KEY -e S3_SECRET_ACCESS_KEY -e S3_ENDPOINT -e S3_BUCKET -e "DEBUG=krawler*" k-atlas:bdpr-latest
```
