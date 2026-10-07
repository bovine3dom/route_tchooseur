INSTALL spatial;
LOAD spatial;
INSTALL h3 FROM community;
LOAD h3;

CREATE TEMP TABLE platforms AS
SELECT TRY(ST_GeomFromText(regexp_replace(WKT, '^<http://www.opengis.net/def/crs/OGC/1\.3/CRS84>\s*', ''))) AS location,
    TRY_CAST(string_split(height, '-') AS USMALLINT[]) AS heights, TRY_CAST(length AS DOUBLE) AS length
FROM read_csv('platforms.csv', header = true, all_varchar = true, delim = ',', quote = '"', escape = '"');

COPY (
    SELECT h3_latlng_to_cell_string(ST_Y(location), ST_X(location), 5) AS index, max(height) AS value
    FROM platforms, unnest(heights) AS h(height)
    GROUP BY index HAVING index IS NOT NULL AND value IS NOT NULL
) TO 'out/platforms/heights-h3-5.csv' (FORMAT CSV);

COPY (
    SELECT h3_latlng_to_cell_string(ST_Y(location), ST_X(location), 9) AS index, max(height) AS value
    FROM platforms, unnest(heights) AS h(height)
    GROUP BY index HAVING index IS NOT NULL AND value IS NOT NULL
) TO 'out/platforms/heights-h3-9.csv' (FORMAT CSV);

COPY (
    SELECT h3_latlng_to_cell_string(ST_Y(location), ST_X(location), 3) AS index, max(length) AS value
    FROM platforms
    WHERE isfinite(length) AND length >= 0
    GROUP BY index HAVING index IS NOT NULL
) TO 'out/platforms/lengths-h3-3.csv' (FORMAT CSV);

COPY (
    SELECT h3_latlng_to_cell_string(ST_Y(location), ST_X(location), 5) AS index, max(length) AS value
    FROM platforms
    WHERE isfinite(length) AND length >= 0
    GROUP BY index HAVING index IS NOT NULL
) TO 'out/platforms/lengths-h3-5.csv' (FORMAT CSV);

COPY (
    SELECT h3_latlng_to_cell_string(ST_Y(location), ST_X(location), 9) AS index, max(length) AS value
    FROM platforms
    WHERE isfinite(length) AND length >= 0
    GROUP BY index HAVING index IS NOT NULL
) TO 'out/platforms/lengths-h3-9.csv' (FORMAT CSV);
