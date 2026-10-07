INSTALL spatial;
LOAD spatial;

COPY (
    SELECT start_lat, end_lat, start_lon, end_lon, max(speed) AS speed
    FROM (
        SELECT ST_X(start_op) AS start_lon, ST_Y(start_op) AS start_lat,
            ST_X(end_op) AS end_lon, ST_Y(end_op) AS end_lat, TRY_CAST(speed AS UINT16) AS speed
        FROM (
            SELECT *,
                TRY(ST_GeomFromText(regexp_replace(startWKT, '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS start_op,
                TRY(ST_GeomFromText(regexp_replace(endWKT, '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS end_op
            FROM read_csv('speeds.csv', header = true, all_varchar = true, delim = ',', quote = '"', escape = '"')
        )
    )
    GROUP BY start_lat, end_lat, start_lon, end_lon
) TO 'speeds.parquet' (FORMAT PARQUET);
