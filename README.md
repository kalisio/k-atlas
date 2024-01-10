# k-atlas

Krawler based jobs to scrape various data related to administrative entities.

## OSM boundaries

This job relies on [osmium](https://osmcode.org/osmium-tool/) to extract administrative boundaries at different level from OSM pbf files.

> [!IMPORTANT]  
> [osmimum](https://osmcode.org/osmium-tool/) must be installed on your system. 

To setup the regions to process, you must export the environment variables `REGIONS` with the [GeoFabrik](https://download.geofabrik.de/) regions. For instance:

```bash
export REGIONS="europe/france;europe/albania"
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
