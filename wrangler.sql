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
select start_lat, end_lat, first(start_lon) start_lon, first(end_lon) end_lon, max(val) val, argmax(val,gpLabel) gpLabel from (
select *,
CASE WHEN gpLabel = 'G1' then 1
    WHEN gpLabel = 'GA' then 2
    WHEN gpLabel = 'GB' then 3
    WHEN gpLabel = 'GC' then 4
    ELSE 5
END val
from 'out.parquet'
where gpLabel in ('G1', 'GA', 'GB','GC')
)
group by start_lat, end_lat
) TO 'mini.parquet' (FORMAT 'parquet');
