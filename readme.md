wip 'where can i go' map for loading gauge (cross sectional width of trains)

done:
- poc extraction of gauges from italian data

todo:
- check extract on more data from https://data-interop.era.europa.eu/dataset-explorer
- find map of gauge enum -> human name
- find dictionary of my gauge enum -> compatible gauge enums
- do some hacky maplibre / deck.gl (maybe?) web app where you can pick a gauge and see which routes are compatible and which are not
    - if there data is too big for maplibre i guess we'll have to convert it to geojson and tile it

- spend a few minutes debugging why the sparql query misses out most of spain. if unfixable go back to julia method



## sparql

https://graph.data.era.europa.eu/sparql with the rinf database

https://data-interop.era.europa.eu/endpoint has a playground that is less rubbish

```sh
curl -H "Accept: text/csv" \
    -H "Content-Type: application/sparql-query" \
    --data-binary @query.sparql \
    https://graph.data.era.europa.eu/repositories/rinf
```
