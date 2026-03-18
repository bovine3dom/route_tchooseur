-- duckdb
INSTALL spatial;
LOAD spatial;
INSTALL h3 FROM community;
LOAD h3;

-- get some error about nanoarrow so use parquet for now
-- although really i dunno why i am using duckdb, i should have just used clickhouse like always
-- INSTALL arrow FROM community;
-- LOAD arrow;
select * from 'out.csv' limit 1;
COPY (
    --select start_lat, end_lat, start_lon, end_lon, gp, gpLabel from (
    select start_lat, end_lat, first(start_lon) start_lon, first(end_lon) end_lon, min(gp) gp, argmin(gpLabel,gp) gpLabel from (
        select sol, ST_X(start_op) start_lon, ST_Y(start_op) start_lat, ST_X(end_op) end_lon, ST_Y(end_op) end_lat, gpLabel, list_last(string_split(gp, '/'))::USMALLINT gp from (
            select sol, ST_GeomFromText(startWkt) start_op, ST_GeomFromText(endWkt) end_op, gp, gpLabel from 'out.csv'
        )
    ) 
    group by sol, start_lat, end_lat
) TO 'out.parquet' (FORMAT 'parquet');

select * from 'out.parquet'
where gpLabel in ('G1', 'GA', 'GB','GC')
limit 10;

select first(gpLabel) gpLabel, gp, count() n from 'out.parquet'
group by all
order by n desc;

COPY (
select start_lat, end_lat, first(start_lon) start_lon, first(end_lon) end_lon, max(val) val, argmax(gpLabel2, val) gpLabel from (
    select *,
    CASE WHEN gpLabel2 = 'G1' then 1
        WHEN gpLabel2 = 'GA' then 2
        WHEN gpLabel2 = 'GB' then 3
        WHEN gpLabel2 = 'G2' then 4
        WHEN gpLabel2 = 'GB1' then 5
        WHEN gpLabel2 = 'GB2' then 6
        WHEN gpLabel2 = 'GC' then 7
        ELSE null
    END val
    from (
        select *,
        CASE 
            WHEN gpLabel IN ('PTc', 'SEc', 'GEC16', 'GC') THEN 'GC'
            WHEN gpLabel IN ('NL2', 'GB2', 'FIN1') THEN 'GB2'
            WHEN gpLabel IN ('PTb+', 'GB1') THEN 'GB1'
            WHEN gpLabel IN ('G2', 'NL1', 'BE3', 'DE3', 'SEa') THEN 'G2'
            WHEN gpLabel IN ('GB', 'GEB16', 'PTb', 'BE2', 'EBV1', 'EBV2') THEN 'GB'
            WHEN gpLabel IN ('GEA16', 'GA', 'DE2', 'BE1') THEN 'GA'
            WHEN gpLabel IN ('FR-3.3', 'G1', 'GHE16') THEN 'G1'
            ELSE NULL 
        END gpLabel2
        from 'out.parquet'
    )
    where val is not null
)
group by start_lat, end_lat
) TO 'mini.parquet' (FORMAT 'parquet');



-- platforms
copy (
    select max(height) as value, index from (
        select ST_GeomFromText(WKT) as location, unnest(split(height, '-')::USMALLINT[]) height, length,
        h3_latLng_to_cell_string(ST_Y(location), ST_X(location), 5) as index
        from 'platforms.csv'
    )
    group by all
) to 'platform_heights/2026-03-19.csv';

copy (
    select max(length) as value, index from (
        select ST_GeomFromText(WKT) as location, unnest(split(height, '-')::USMALLINT[]) height, length,
        h3_latLng_to_cell_string(ST_Y(location), ST_X(location), 5) as index
        from 'platforms.csv'
    )
    group by all
) to 'platform_lengths/2026-03-19.csv';
