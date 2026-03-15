-- duckdb
INSTALL spatial;
LOAD spatial;

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
        WHEN gpLabel2 = 'G2' then 2
        WHEN gpLabel2 = 'GA' then 3
        WHEN gpLabel2 = 'GB' then 4
        WHEN gpLabel2 = 'GB1' then 5
        WHEN gpLabel2 = 'GC' then 6
        ELSE null
    END val
    from (
        select *,
        CASE 
            WHEN gpLabel IN ('GC', 'DE3', 'GCZ3', 'SEa', 'FIN1', 'S', 'GEC16') THEN 'GC'
            WHEN gpLabel IN ('GB1') THEN 'GB1'
            WHEN gpLabel IN ('GB', 'FR-3.3', 'EBV2', 'NL2', 'FS', 'GČD', 'GEB16') THEN 'GB'
            WHEN gpLabel IN ('GA', 'GEA16') THEN 'GA'
            WHEN gpLabel IN ('G2', 'DE2') THEN 'G2'
            WHEN gpLabel IN ('G1', 'DE1', 'EBV1', 'BE1', 'BE2', 'BE3', 'NL1', 'PTb', 'PTb+', 'GHE16') THEN 'G1'
            ELSE NULL 
        END gpLabel2
        from 'out.parquet'
    )
    where val is not null
)
group by start_lat, end_lat
) TO 'mini.parquet' (FORMAT 'parquet');
