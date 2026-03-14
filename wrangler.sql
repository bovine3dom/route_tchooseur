-- duckdb
INSTALL spatial;
LOAD spatial;

-- get some error about nanoarrow so use parquet for now
-- although really i dunno why i am using duckdb, i should have just used clickhouse like always
-- INSTALL arrow FROM community;
-- LOAD arrow;
select * from 'out.csv' limit 1;
COPY (
    select start_lat, end_lat, first(start_lon) start_lon, first(end_lon) end_lon, min(gp) gp, argmin(gpLabel,gp) gpLabel from (
        select sol, ST_X(start_op) start_lon, ST_Y(start_op) start_lat, ST_X(end_op) end_lon, ST_Y(end_op) end_lat, gpLabel, list_last(string_split(gp, '/'))::USMALLINT gp from (
            select sol, ST_GeomFromText(startWkt) start_op, ST_GeomFromText(endWkt) end_op, gp, gpLabel from 'out.csv'
        )
    ) group by sol, start_lat, end_lat
) TO 'out.parquet' (FORMAT 'parquet');
