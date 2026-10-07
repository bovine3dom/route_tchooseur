INSTALL spatial;
LOAD spatial;

-- Keep raw fields and each reported category/speed pair. Do not rank categories.
COPY (
    -- UIC Loading Guidelines, Volume 1, section 3.1 (01/04/2026). See track_load.md.
    WITH load_limits(load_category, max_axle_load_t, max_mass_per_m_t) AS (
        VALUES
            ('A',  16.0, 5.0),
            ('B1', 18.0, 5.0),
            ('B2', 18.0, 6.4),
            ('C2', 20.0, 6.4),
            ('C3', 20.0, 7.2),
            ('C4', 20.0, 8.0),
            ('D2', 22.5, 6.4),
            ('D3', 22.5, 7.2),
            ('D4', 22.5, 8.0),
            ('E4', 25.0, 8.0),
            ('E5', 25.0, 8.8)
    ), loads AS (
        SELECT *,
            TRY(ST_GeomFromText(regexp_replace(startWKT,
                '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS start_op,
            TRY(ST_GeomFromText(regexp_replace(endWKT,
                '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS end_op,
            coalesce(nullif(loadCategoryCode, ''), nullif(loadCategoryLabel, '')) AS load_category
        FROM read_csv('loads.csv', header = true, all_varchar = true,
                      delim = ',', quote = '"', escape = '"')
    )
    SELECT loads.* EXCLUDE (start_op, end_op),
        TRY(ST_X(start_op)) AS start_lon, TRY(ST_Y(start_op)) AS start_lat,
        TRY(ST_X(end_op)) AS end_lon, TRY(ST_Y(end_op)) AS end_lat,
        TRY_CAST(loadSpeed AS INTEGER) AS load_speed,
        CASE
            WHEN load_limits.load_category IS NOT NULL
                 OR load_category IN ('D4xL', 'HS17') THEN 'km/h'
            WHEN regexp_full_match(load_category, 'RA([1-9]|10)') THEN 'mph'
        END AS load_speed_unit,
        CASE load_speed_unit
            WHEN 'mph' THEN load_speed * 1.609344
            WHEN 'km/h' THEN load_speed::DOUBLE
        END AS load_speed_kmh,
        max_axle_load_t::DOUBLE AS max_axle_load_t,
        max_mass_per_m_t::DOUBLE AS max_mass_per_m_t
    FROM loads
    LEFT JOIN load_limits USING (load_category)
) TO 'loads.parquet' (FORMAT 'parquet');
