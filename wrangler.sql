INSTALL spatial;
LOAD spatial;

COPY (
    SELECT start_lat, end_lat, first(start_lon) AS start_lon, first(end_lon) AS end_lon,
        min(gp) AS gp, arg_min(gpLabel, gp) AS gpLabel
    FROM (
        SELECT sol, ST_X(start_op) AS start_lon, ST_Y(start_op) AS start_lat,
            ST_X(end_op) AS end_lon, ST_Y(end_op) AS end_lat, gpLabel,
            TRY_CAST(list_last(string_split(gp, '/')) AS USMALLINT) AS gp
        FROM (
            SELECT *,
                TRY(ST_GeomFromText(regexp_replace(startWKT, '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS start_op,
                TRY(ST_GeomFromText(regexp_replace(endWKT, '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS end_op
            FROM read_csv('out.csv', header = true, all_varchar = true, delim = ',', quote = '"', escape = '"')
        )
    )
    GROUP BY sol, start_lat, end_lat
) TO 'out.parquet' (FORMAT PARQUET);

COPY (
    SELECT DISTINCT gp AS gauge_number, gpLabel AS gauge_label FROM 'out.parquet' ORDER BY gp
) TO 'gauge_labels.csv' (FORMAT CSV);
