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


google claims

```
{
  "France": {
    "FR-3.3":["G1", "GA", "GB"]
  },
  "Germany": {
    "DE1":["G1"],
    "DE2": ["G1", "G2"],
    "DE3":["G1", "GA", "GB", "GC"]
  },
  "Belgium": {
    "BE1": ["G1"],
    "BE2": ["G1"],
    "BE3":["G1"]
  },
  "Netherlands": {
    "NL1": ["G1"],
    "NL2": ["G1", "GA", "GB"]
  },
  "Italy": {
    "FS": ["G1", "GA", "GB"]
  },
  "Switzerland": {
    "EBV O1": ["G1"],
    "EBV O2":["G1", "GA", "GB"],
    "GCZ3":["G1", "GA", "GB", "GC"]
  },
  "Sweden": {
    "SEa":["G1", "GA", "GB", "GC"],
    "SEc": ["G1", "GA", "GB", "GC"]
  },
  "Finland": {
    "FIN1":["G1", "GA", "GB", "GC"]
  },
  "Spain": {
    "GEB16": ["G1"],
    "GEC16": ["G1"]
  },
  "Portugal": {
    "PTb": ["G1"],
    "PTc": ["G1"]
  },
  "Great Britain": {
    "W6": [],
    "W8": [],
    "W10":[],
    "W12": [],
    "UK1":[] 
  }
}
```
but we're missing quite a few gauges:

```
┌─────────┬────────┬────────┐
│ gpLabel │   gp   │   n    │
│ varchar │ uint16 │ int64  │
├─────────┼────────┼────────┤
│ G2      │     60 │ 120824 │
│ DE3     │     50 │  67442 │
│ DE1     │    190 │  58865 │
│ GA      │     10 │  57261 │
│ DE2     │    200 │  38206 │
│ GI2     │    350 │  29336 │
│ G1      │     40 │  22835 │
│ FR-3.3  │    120 │  18482 │
│ GB      │     20 │  17038 │
│ EBV2    │    432 │  15504 │
│ GB1     │     70 │  12945 │
│ GC      │     30 │  10080 │
│ EBV1    │    431 │   4238 │
│ BE2     │    100 │   2696 │
│ SEa     │    170 │   1545 │
│ NL1     │    400 │   1033 │
│ PTb+    │    140 │    799 │
│ FIN1    │    160 │    799 │
│ other   │    500 │    526 │
│ GCZ3    │    419 │    494 │
│ S       │    260 │    310 │
│ IRL1    │    310 │    274 │
│ GČD     │    420 │    226 │
│ GEC16   │    300 │    203 │
│ PTb     │    130 │    202 │
│ GEI2    │    422 │    192 │
│ GEB16   │    290 │    137 │
│ GI3     │    360 │    115 │
│ FS      │    250 │    112 │
│ NL2     │    410 │    112 │
│ GHE16   │    270 │     89 │
│ BE1     │     90 │     67 │
│ GED10   │    380 │     59 │
│ BE3     │    110 │     55 │
│ GEE10   │    370 │     52 │
│ GEI3    │    423 │      8 │
│ GEA16   │    280 │      1 │
└─────────┴────────┴────────┘
```
