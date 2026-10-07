INSTALL spatial;
LOAD spatial;

-- Keep raw fields and each reported category/speed pair. Do not rank categories.
COPY (
    WITH loads AS (
        SELECT *,
            TRY(ST_GeomFromText(regexp_replace(startWKT,
                '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS start_op,
            TRY(ST_GeomFromText(regexp_replace(endWKT,
                '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS end_op,
            coalesce(nullif(loadCategoryCode, ''), nullif(loadCategoryLabel, '')) AS load_category
        FROM read_csv('loads.csv', header = true, all_varchar = true)
    )
    SELECT * EXCLUDE (start_op, end_op),
        TRY(ST_X(start_op)) AS start_lon, TRY(ST_Y(start_op)) AS start_lat,
        TRY(ST_X(end_op)) AS end_lon, TRY(ST_Y(end_op)) AS end_lat,
        TRY_CAST(loadSpeed AS INTEGER) AS load_speed,
        CASE
            WHEN load_category IN ('A', 'B1', 'B2', 'C2', 'C3', 'C4',
                                   'D2', 'D3', 'D4', 'D4xL', 'E4', 'E5', 'HS17') THEN 'km/h'
            WHEN regexp_full_match(load_category, 'RA([1-9]|10)') THEN 'mph'
        END AS load_speed_unit
    FROM loads
) TO 'loads.parquet' (FORMAT 'parquet');
