#/!bin/sh

store='admin-express/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03/ADMIN-EXPRESS-COG-CARTO/1_DONNEES_LIVRAISON_2023-05-03/ADECOGC_3-2_SHP_WGS84G_FRA'

echo "<> generating boundaries mbtiles"
tippecanoe -f -o $store/ARRONDISSEMENT.mbtiles -Z12 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Larrondissement:<(cat $store/ARRONDISSEMENT.geojson)
tippecanoe -f -o $store/COMMUNE.mbtiles -Z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lcommune:<(cat $store/COMMUNE.geojson)
tippecanoe -f -o $store/DEPARTEMENT.mbtiles -Z7 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Ldepartement:<(cat $store/DEPARTEMENT.geojson)
tippecanoe -f -o $store/CANTON.mbtiles -Z7 -z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lcanton:<(cat $store/CANTON.geojson)
tippecanoe -f -o $store/EPCI.mbtiles -Z6 -z9 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lecpi:<(cat $store/EPCI.geojson)
tippecanoe -f -o $store/COLLECTIVITE_TERRITORIALE.mbtiles -Z5 -z8 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lcollectivite-territoriale:<(cat $store/COLLECTIVITE_TERRITORIALE.geojson)
tippecanoe -f -o $store/REGION.mbtiles -Z3 -z10 --coalesce-densest-as-needed --extend-zooms-if-still-dropping --drop-smallest-as-needed -Lregion:<(cat $store/REGION.geojson)


echo "<> generating toponyms mbtiles"
tippecanoe -f -o $store/ARRONDISSEMENT-toponyms.mbtiles -Z12 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Larrondissement_toponyme:<(cat $store/ARRONDISSEMENT-toponyms.geojson)
tippecanoe -f -o $store/COMMUNE-toponyms.mbtiles -Z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lcommune_toponyme:<(cat $store/COMMUNE-toponyms.geojson)
tippecanoe -f -o $store/DEPARTEMENT-toponyms.mbtiles -Z7 -z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Ldepartement_toponyme:<(cat $store/DEPARTEMENT-toponyms.geojson)
tippecanoe -f -o $store/CANTON-toponyms.mbtiles -Z7 -z10 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lcanton_toponyme:<(cat $store/CANTON-toponyms.geojson)
tippecanoe -f -o $store/EPCI-toponyms.mbtiles -Z6 -z9 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lepci_toponyme:<(cat $store/EPCI-toponyms.geojson)
tippecanoe -f -o $store/COLLECTIVITE_TERRITORIALE-toponyms.mbtiles -Z5 -z8 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lcollectivite-territoriale_toponyme:<(cat $store/COLLECTIVITE_TERRITORIALE-toponyms.geojson)
tippecanoe -f -o $store/REGION-toponyms.mbtiles -Z5 -z8 --coalesce-densest-as-needed -r1 --cluster-distance=10 -Lregion_toponyme:<(cat $store/REGION-toponyms.geojson)

echo "<> merging toponyms mbtiles"
tile-join -f -o admin-express/admin-express-toponyms.mbtiles \
  $store/ARRONDISSEMENT-toponyms.mbtiles \
  $store/COMMUNE-toponyms.mbtiles \
  $store/DEPARTEMENT-toponyms.mbtiles \
  $store/CANTON-toponyms.mbtiles \
  $store/EPCI-toponyms.mbtiles \
  $store/DEPARTEMENT-toponyms.mbtiles \
  $store/COLLECTIVITE_TERRITORIALE-toponyms.mbtiles \
  $store/REGION-toponyms.mbtiles

echo "<> merging boundaries mbtiles"
tile-join -f -o admin-express/admin-express-polygons.mbtiles \
  $store/ARRONDISSEMENT.mbtiles \
  $store/COMMUNE.mbtiles \
  $store/DEPARTEMENT.mbtiles \
  $store/CANTON.mbtiles \
  $store/EPCI.mbtiles \
  $store/DEPARTEMENT.mbtiles \
  $store/COLLECTIVITE_TERRITORIALE.mbtiles \
  $store/REGION.mbtiles

echo "<> merging all mbtiles"
tile-join -f -o admin-express/admin-express.mbtiles admin-express/admin-express-polygons.mbtiles admin-express/admin-express-toponyms.mbtiles