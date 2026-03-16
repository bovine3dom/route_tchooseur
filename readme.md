wip 'where can i go' map for loading gauge (cross sectional width of trains)

done:
- poc extraction of gauges from italian data

todo:
- check extract on more data from https://data-interop.era.europa.eu/dataset-explorer
- find map of gauge enum -> human name
    - i think we have enough sparql data to make one of these
- find dictionary of my gauge enum -> compatible gauge enums
    - this is trickier, it seems like it's locked away in a $500 standards document, EN 15273-2
- do some hacky maplibre / deck.gl (maybe?) web app where you can pick a gauge and see which routes are compatible and which are not
    - if there data is too big for maplibre i guess we'll have to convert it to geojson and tile it

- spend a few minutes debugging why the sparql query misses out most of spain. if unfixable go back to julia method. it's not the groupby that's causing it



## sparql

https://graph.data.era.europa.eu/sparql with the rinf database

https://data-interop.era.europa.eu/endpoint has a playground that is less rubbish

```sh
curl -H "Accept: text/csv" \
    -H "Content-Type: application/sparql-query" \
    --data-binary @query.sparql \
    https://graph.data.era.europa.eu/repositories/rinf
```

## Gauge compatibilities

I manually transcribed a load of gauges from standards in gauge_geometries.sql

I kept finding that the lower parts of the gauges were mutually incompatible with each other, so I have only transcribed the upper parts, assuming that they then go straight down. Additionally, the gauges are all symmetric, so I have only transcribed the right hand side.

## Results

See track_to_biggest_international_train.csv, train_to_possible_tracks.csv, track_to_possible_trains.csv
