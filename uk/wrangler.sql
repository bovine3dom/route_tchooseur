INSTALL spatial;
LOAD spatial;

CREATE TEMP TABLE uk_loading_gauges_lor AS (
   select W10,W10A,W12,W6A,W7,W8,W9,W9PLUS, st_flipcoordinates(st_transform(Geom, 'EPSG:4326')) as Geom from (
        select thanks_will.ELR,
        list_contains(list(W10), 'Y') as W10,
        list_contains(list(W10A), 'Y') as W10A,
        list_contains(list(W12), 'Y') as W12,
        (list_contains(list(W6), 'Y')) or
        (list_contains(list(W6A), 'Y')) as W6A,
        list_contains(list(W7), 'Y') as W7,
        list_contains(list(W8), 'Y') as W8,
        list_contains(list(W9), 'Y') as W9,
        list_contains(list(W9PLUS), 'Y') as W9PLUS
        from read_csv('nesa_wrangled/*.csv', union_by_name=true) nesa
        join 'elr_to_line_of_route.csv' thanks_will on nesa."LINE OF ROUTE" = thanks_will."Line of route"
        group by all
    )
    left join st_read('network-rail-gis/network-model/VectorLinks/NetworkLinks.shp') using (ELR)
    where Geom is not null
);
copy (
   select * from uk_loading_gauges_lor
) TO 'out.parquet' (FORMAT PARQUET);

copy (
   WITH numbered_data AS (
       SELECT *, row_number() OVER () AS _rn
       FROM uk_loading_gauges_lor
   ),
   stacked AS (
       UNPIVOT numbered_data
       ON COLUMNS('^W.*')
       INTO NAME gauge_name VALUE is_active
   ),
   labels AS (
       SELECT 
           _rn,
           list(gauge_name) AS gauge_labels
       FROM stacked
       WHERE is_active = true 
       GROUP BY _rn
   )
   SELECT 
       ST_Y(ST_PointN(b.geom, b.i)) AS latitude_start,
       ST_X(ST_PointN(b.geom, b.i)) AS longitude_start,
       ST_Y(ST_PointN(b.geom, b.i + 1)) AS latitude_end,
       ST_X(ST_PointN(b.geom, b.i + 1)) AS longitude_end,
       unnest(l.gauge_labels) AS gauge_label
   FROM (
       SELECT 
           *, 
           UNNEST(range(1, ST_NPoints(geom)))::int32 AS i
       FROM numbered_data
   ) b
   LEFT JOIN labels l 
       ON b._rn = l._rn
) TO 'uk.parquet' (FORMAT PARQUET);
