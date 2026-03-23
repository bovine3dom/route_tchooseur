-- duckdb
install 'spatial';
load 'spatial';

select * from st_read('network-rail-gis/network-model/VectorLinks/NetworkLinks.shp') limit 1;

-- eughghhghghghgh
select * from st_read('network-rail-gis/network-model/VectorLinks/NetworkLinks.shp') where ELR = 'NW1001';


-- cool. so. ELR is ELR, then we have L_M_FROM and L_M_TO. excep ELR and M and Ch are missing from all the tables we care about.


--- i guess i can do some cheating and find line of route -> elr?
copy (
    -- nb: duckdb secretly doesn't support */*.xlsx and will just read the first file
   select distinct * from (
      select distinct "Line of route", ELR from 'nesa_ocr/Anglia/*.xlsx'
      union
      select distinct "Line of route", ELR from 'nesa_ocr/Kent-Sussex-Wessex/*.xlsx'
      union
      select distinct "Line of route", ELR from 'nesa_ocr/London-North-Eastern/*.xlsx'
      union
      select distinct "Line of route", ELR from 'nesa_ocr/London-North-Western-North/*.xlsx'
      union
      select distinct "Line of route", ELR from 'nesa_ocr/London-North-Western-South/*.xlsx'
      union
      select distinct "Line of route", ELR from 'nesa_ocr/Scotland/*.xlsx'
      union
      select distinct "Line of route", ELR from 'nesa_ocr/Western/*.xlsx'
      union
       -- source: https://www.geofurlong.com/lor/tables/, fill in the missing ones
      select LOR as 'Line of route', unnest(string_split(ELRs, ', ')) ELR from 'geofusion_snippet.csv'
   )
) to 'elr_to_line_of_route.csv';


select * from st_read('network-rail-gis/network-model/VectorLinks/NetworkLinks.shp') where ELR = 'BOK3';

-- going by best case scenario, which is probably daft, but
-- for some reason there's duplicates of the entire north west that say NO to everything
-- pretty sure w6 gauge doesn't exist and it's really w6a
create table uk_loading_gauges_lor as (
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
) to 'out.parquet';

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
) to 'uk.parquet'; -- still can't get arrow to work :(
