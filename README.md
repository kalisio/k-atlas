# k-atlas

[![Latest Release](https://img.shields.io/github/v/tag/kalisio/k-atlas?sort=semver&label=latest)](https://github.com/kalisio/k-atlas/releases)
[![CI](https://github.com/kalisio/k-atlas/actions/workflows/main.yaml/badge.svg)](https://github.com/kalisio/k-atlas/actions/workflows/main.yaml)
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

If you only need some languages for i18n properties (`name`, `alt_name` and `official_name`) in database you can select the target languages like this:
```bash
export LANGUAGES="en;fr"
```

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

Last but not least, launch the `generate-osm-boundaries-mbtiles.sh` script to generate a MBTiles file from GeoJson files produced by the job or `generate-osm-boundaries-gpkg.sh` script to generate a GPKG file.

> [!IMPORTANT]  
> GPKG generation requires the `ogrmerge` tool to be installed, if you are using an unstable debian version you can do this, which is not [recommanded](https://wiki.debian.org/DontBreakDebian#Don.27t_make_a_FrankenDebian) for a stable version:
```bash
sudo nano /etc/apt/sources.list
# Edit file and add this line
deb http://deb.debian.org/debian/ unstable main contrib non-free
# Then install GDAL dev version to get ogrmerge
sudo apt update
sudo apt-get install libgdal-dev
```

To avoid generating data multiple times you can easily dump/restore it from/to MongoDB databases:
```bash
mongodump --host=localhost --port=27017 --username=user --password=password --db=atlas --collection=osm-boundaries --gzip --out dump
mongorestore --db=atlas --gzip --host=mongodb.example.net --port=27018 --username=user --password=password --collection=osm-boundaries dump/atlas/osm-boundaries.bson.gz
```
If you dump the collection first recreate required indices to speed-up data access with the Mongo shell like:
```
db['admin-express'].createIndexes([{ geometry: '2dsphere' }, { 'properties.layer': 1 }, { geometry: '2dsphere', 'properties.layer': 1 }])
db['osm-boundaries'].createIndexes([{ geometry: '2dsphere' }, { 'properties.admin_level': 1 }, { geometry: '2dsphere', 'properties.admin_level': 1 }])
```

## Admin-Express

This job relies on archive shape files from IGN and the [mapshaper](https://github.com/mbloch/mapshaper) and [7z](https://www.7-zip.org/download.html) tools.

https://geoservices.ign.fr/documentation/diffusion/telechargement-donnees-libres.html#admin-express

### with French Polynesia

The job has been updated to include French Polynesia data in the admin-express dataset.

The script requires the following tools:
 - `mapshaper` (can be installed with `npm install -g mapshaper`)
 - `wget`, `7z`, `tippecanoe` and `tile-join`. All of those can probably be found as packages in your favorite distribution (`apt install 7z wget tippecanoe`).

French Polynesia data is fetched from [here](https://www.data.gouv.fr/fr/datasets/limites-geographiques-administratives/) and [here](https://www.tefenua.data.gov.pf/maps/6e392df616c949309eda19656450562a/about) for the INSEE codes.

The script reprojects and patches the French Polynesia data to match the Admin Express schema, adding properties like `INSEE_COM`, `INSEE_DEP`, `NOM`, `NOM_M` and `POPULATION` to it. It then merges with the Admin Express dataset to build the final mbtiles.

## BDPR

This job relies on archive shape files from IGN and the [mapshaper](https://github.com/mbloch/mapshaper) and [7z](https://www.7-zip.org/download.html) tools.

https://geoservices.ign.fr/documentation/diffusion/telechargement-donnees-libres.html#bdpr

## BDTOPAGE

This job relies on :

- [7z](https://www.7-zip.org/download.html) to extract archive shape files from eaufrance
- [mapshaper](https://github.com/mbloch/mapshaper) to convert shape files to GeoJson
- [tippecanoe](https://github.com/felt/tippecanoe) to generate MBTiles (optional)



BDTOPAGE contains hydrographic data for the french territory and includes the following layers:
- Watercourses
- Water bodies
- Elementary surfaces
- Hydrographic sections
- Hydrographic nodes
- Land-sea boundaries 
- Hydrographic basins (medium scale) 
- Topographic watershed (medium scale)


To select specific layers to process you can setup the `TOPAGE_LAYERS` environment variable with a comma-separated list of `<layer_name>=<output_name>` entries like this:

```bash
export TOPAGE_LAYERS="BassinHydrographique_FXX=hydrographic-basins,BassinVersantTopographique_FXX=topographic-watersheds"
```

Run the job with:
```
krawler --jobfile ../k-atlas/jobfile-bdtopage.js
```

bash script to generate mbtiles from bdtopage data:
```bash
./generate-bdtopage-mbtiles.sh <output_dir> <geojson_file> <layer_name(optional)> 
```

Two directories will be created :
- `bdtopage-output/geojson/` containing one geojson file per layer
- `bdtopage-output/mbtiles/` containing one mbtiles file per layer 
- `bdtopage-output/shapefiles/` containing the original shapefiles unzipped
- `bdtopage-workdir/` temporary working directory

## Development

To debug you can run this command from a local krawler install `node --inspect . ../k-atlas/jobfile-bdpr.js`.

To run it on the infrastructure we use Docker images based on the provided Docker files, if you'd like to test it manually you can clone the repo then do:
```
docker build --build-arg KRAWLER_TAG=latest -f dockerfile.bdpr -t k-atlas/bdpr-latest .
docker run --name bdpr --network=host --rm -e S3_ACCESS_KEY -e S3_SECRET_ACCESS_KEY -e S3_ENDPOINT -e S3_BUCKET -e "DEBUG=krawler*" k-atlas:bdpr-latest
```
