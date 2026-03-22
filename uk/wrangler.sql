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
) to 'nesa_wrangled/elr_to_line_of_route.csv';

select * from st_read('network-rail-gis/network-model/VectorLinks/NetworkLinks.shp') where ELR = 'BOK3';

-- ok so let's go by worst case instead
copy (
    select W7, st_flipcoordinates(st_transform(Geom, 'EPSG:4326')) as Geom from (
        select ELR,
        list_contains(list(W7), 'Y') and NOT list_contains(list(W7), 'N') as W7
        from read_csv('nesa_wrangled/*.tsv', union_by_name=true)
        join 'nesa_wrangled/elr_to_line_of_route.csv' using ("Line of route")
        group by all
    )
    left join st_read('network-rail-gis/network-model/VectorLinks/NetworkLinks.shp') using (ELR)
) to 'out.parquet';
