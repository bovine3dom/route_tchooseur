INSTALL spatial;
LOAD spatial;

DROP TABLE IF EXISTS gauge_shapes;
CREATE TABLE gauge_shapes (gauge_name VARCHAR, geom GEOMETRY);

-- Right-half upper profiles in millimetres.
-- DE1 is estimated from an unlabelled diagram:
-- https://www.dbcargo.com/rail-de-en/logistics-news/the-abc-of-freight-transport-loading-gauge-12978800
-- DE2 approximates a curved profile. GEE10 uses a low-resolution diagram.
-- EBV1 and EBV2 are estimated from:
-- https://www.stuva.de/downloads/publikationen/pdf/SH_AK_TuSa_2011_screen.pdf
-- S uses an approximate static-to-kinematic conversion of a structure-gauge diagram:
-- https://masto.ai/@ignaloidas@not.acu.lt/116250997139070045
INSERT INTO gauge_shapes VALUES
('W6A', ST_GeomFromText('
    POLYGON ((
            0 0, 1410 0,
            1410 3080, 1345 3300, 1220 3440, 795 3750, 152.5 3965, 0 3965, 0 0
    ))
')),
('W7', ST_GeomFromText('
    POLYGON ((
            0 0, 1410 0,
            1410 3080, 1345 3300, 1240 3418, 1240 3531, 1095 3531, 795 3570, 452.5 3965, 0 3965, 0 0
    ))
')),
('W8', ST_GeomFromText('
    POLYGON ((
            0 0, 1410 0,
            1410 3080, 1345 3300, 1271 3568, 1264 3618, 976 3618, 795 3750, 152.5 3965, 0 3965, 0 0
    ))
')),
('W8A', ST_GeomFromText('
    POLYGON ((
            0 0, 1321.5 0,
            1321.5 3300, 1262.5 3512, 1262.5 3635, 0 3635, 0 0
    ))
')),
('W9', ST_GeomFromText('
    POLYGON ((
            0 0, 1312.5 0,
            1312.5 1000, 1398 1000, 1398 3080, 1333 3300, 1312.5 3323, 1312.5 3695, 1262.5 3701, 1262.5 3715, 678 3785, 140 3965, 0 3965, 0 0
    ))
')),
('W9A', ST_GeomFromText('
    POLYGON ((
            0 0, 1312.5 0,
            1312.5 3730, 1125 3730, 0 3866, 0 0
    ))
')),
('W10', ST_GeomFromText('
    POLYGON ((
            0 0, 1262.5 0,
            1262.5 3850, 1256 3891, 0 3891, 0 0
    ))
')),
('W10A', ST_GeomFromText('
    POLYGON ((
            0 0, 1262.5 0,
            1262.5 3891, 0 3891, 0 0
    ))
')),
-- W12 has multiple published profiles; this model uses one profile.
('W12', ST_GeomFromText('
    POLYGON ((
            0 0, 1312.5 0,
            1312.5 3850, 1287.5 3896, 587.5 3896, 12.5 3965, 0 3965, 0 0
    ))
')),
('S', ST_GeomFromText('
    POLYGON ((
            0 0, 1932 0,
            1932 4028, 1546 4733, 1065 5337, 0 5337, 0 0
    ))
')),
('PTb', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3550, 1360 4110, 1000 4500, 0 4500, 0 0
    ))
')),
('PTb+', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3550, 1440 4210, 1000 4500, 0 4500, 0 0
    ))
')),
('PTc', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3550, 1540 4700, 0 4700, 0 0
    ))
')),
('DE1', ST_GeomFromText('
    POLYGON ((
            0 0, 1575 0,
            1575 3500, 1395 3805, 690 4650, 0 4650, 0 0
    ))
')),
('DE2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3530,
            1510 3765, 1401 4025, 1064 4335,
            785 4680, 0 4680, 0 0
    ))
')),
('DE3', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3530, 1409 4216, 785 4680, 0 4680, 0 0
    ))
')),
('NL1', ST_GeomFromText('
    POLYGON ((
            0 0, 1800 0,
            1800 1600, 1645 3530, 1470 3835, 1085 4310, 785 4680, 0 4680, 0 0
    ))
')),
('NL2', ST_GeomFromText('
    POLYGON ((
            0 0, 1800 0,
            1800 1600, 1800 2100, 1645 3530, 1540 4700, 0 4700, 0 0
    ))
')),
('GHE16', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3320, 1580 3700, 1250 4100, 800 4330, 0 4330, 0 0
    ))
')),
('GEA16', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3320, 1580 3700, 1250 4100, 761 4350, 0 4350, 0 0
    ))
')),
('GEB16', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3320, 1580 3700, 1360 4110, 761 4350, 0 4350, 0 0
    ))
')),
('GEC16', ST_GeomFromText('
    POLYGON ((
            0 0, 1720 0,
            1720 3320, 1540 4700, 0 4700, 0 0
    ))
')),
('GEE10', ST_GeomFromText('
    POLYGON ((
            0 0, 1530 0,
            1530 3550, 1185 3900, 500 4100, 0 4100, 0 0
    ))
')),
('GED10', ST_GeomFromText('
    POLYGON ((
            0 0, 1530 0,
            1530 3550, 1150 3800, 750 3900, 0 3900, 0 0
    ))
')),
('FIN1', ST_GeomFromText('
    POLYGON ((
            0 0, 1800 0,
            1800 3500, 1700 3500, 1700 4000, 1500 4600, 900 5300, 0 5300, 0 0
    ))
')),
('SEa', ST_GeomFromText('
    POLYGON ((
            0 0, 1850 0,
            1850 3780, 840 4790, 0 4790, 0 0
    ))
')),
('SEc', ST_GeomFromText('
    POLYGON ((
            0 0, 1980 0,
            1980 4990, 0 4990, 0 0
    ))
')),
('BE1', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3550, 1500 3700, 1310 4010, 1025 4310, 700 4510, 300 4630, 0 4630, 0 0
    ))
')),
('BE2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3550, 1409 4216, 1324 4216, 700 4510, 300 4630, 0 4630, 0 0
    ))
')),
('BE3', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3550, 1409 4218, 785 4680, 0 4680, 0 0
    ))
')),
('FR-3.3', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3250, 1525 3500, 1475 3700, 1350 3900, 1100 4100, 550 4350, 0 4350, 0 0
    ))
')),
('EBV1', ST_GeomFromText('
    POLYGON ((
            0 0, 1900 0,
            1900 3370, 1650 3920, 1020 4570, 0 4570, 0 0
    ))
')),
('EBV2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3530, 1360 4110, 765 4650, 0 4650, 0 0
    ))
')),
('G1', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3250, 1425 3700, 1120 4010, 525 4310, 0 4310, 0 0
    ))
')),
('G2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3530, 1470 3835, 785 4680, 0 4680, 0 0
    ))
')),
('GA', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3250, 1360 3880, 1090 4080, 545 4350, 0 4350, 0 0
    ))
')),
('GB', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3250, 1360 4110, 545 4350, 0 4350, 0 0
    ))
')),
('GB1', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3250, 1440 4210, 545 4350, 0 4350, 0 0
    ))
')),
('GB2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3250, 1450 4350, 0 4350, 0 0
    ))
')),
('GC', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,
            1645 3550, 1540 4700, 0 4700, 0 0
    ))
'));

COPY (
    SELECT g_inner.gauge_name AS our_train, list(g_outer.gauge_name) AS possible_tracks
    FROM gauge_shapes g_inner, gauge_shapes g_outer
    WHERE ST_Covers(g_outer.geom, g_inner.geom)
    GROUP BY our_train
    ORDER BY length(possible_tracks) DESC
) TO 'train_to_possible_tracks.csv' (FORMAT CSV);

COPY (
    SELECT g_outer.gauge_name AS our_tracks, list(g_inner.gauge_name) AS possible_trains
    FROM gauge_shapes g_inner, gauge_shapes g_outer
    WHERE ST_Covers(g_outer.geom, g_inner.geom)
    GROUP BY our_tracks
    ORDER BY length(possible_trains) DESC
) TO 'track_to_possible_trains.csv' (FORMAT CSV);

COPY (
    SELECT DISTINCT ON (the_track) gs.our_train, the_track, universality
    FROM (
        SELECT g_inner.gauge_name AS our_train, g_outer.gauge_name AS the_track
        FROM gauge_shapes g_inner, gauge_shapes g_outer
        WHERE ST_Covers(g_outer.geom, g_inner.geom)
    ) gs
    LEFT JOIN (
        SELECT g_inner.gauge_name AS our_train, count(*) AS universality
        FROM gauge_shapes g_inner, gauge_shapes g_outer
        WHERE g_inner.gauge_name IN ('G1', 'G2', 'GB1', 'GB2', 'GA', 'GB', 'GC')
          AND ST_Covers(g_outer.geom, g_inner.geom)
        GROUP BY our_train
    ) gu ON gu.our_train = gs.our_train
    ORDER BY gu.universality ASC
) TO 'track_to_biggest_international_train.csv' (FORMAT CSV);

COPY (
    SELECT gauge_name, ST_Area(geom) AS area FROM gauge_shapes ORDER BY area DESC
) TO 'gauge_areas.csv' (FORMAT CSV);

COPY (
    SELECT gauge_name, ST_AsGeoJSON(geom) AS geometry FROM gauge_shapes
) TO 'polygons.json' (FORMAT JSON);
