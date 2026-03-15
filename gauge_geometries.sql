INSTALL spatial;
LOAD spatial;

DROP TABLE IF EXISTS gauge_shapes;
CREATE TABLE gauge_shapes (
    gauge_name VARCHAR,
    geom GEOMETRY
);

-- nb: we only model the right side
INSERT INTO gauge_shapes VALUES 
-- some liberties taken with the lower parts. NB: lots share G1 lower parts. all kinematic gauges.
-- this is mad but preview on https://wktmap.com/ with EPSG:3857
-- so, afaict, all belgian gauges are incompatible with international ones? they're both bigger and smaller
-- which seems implausible, especially given that the high speed line claims to be BE2 https://data-interop.era.europa.eu/describe#http%3A%2F%2Fdata.europa.eu%2F949%2FfunctionalInfrastructure%2Ftracks%2Fd5e686f1037c0ee60ea2f6576dab009107590528
('FIN1', ST_GeomFromText('
    POLYGON ((
            0 0, 865 0, 865 125, 1300 125, 1500 330, 1700 330, 1700 1250, 1800 1250,
            1800 3500, 1700 3500, 1700 4000, 1500 4600, 900 5300, 0 5300, 0 0
    ))
')),
('SEa', ST_GeomFromText('
    POLYGON ((
            0 50, 1330 50, 1430 150, 1430 305, 1510 385, 1635 385, 1635 1200, 1850 1200,
            1850 3780, 840 4790, 0 4790, 0 50
    ))
')),
('SEc', ST_GeomFromText('
    POLYGON ((
            0 50, 1330 50, 1430 150, 1430 305, 1510 385, 1635 385, 1635 770, 1860 770, 1980 1300, 1980 4990, 0 4990, 0 50
    ))
')),
('BE1', ST_GeomFromText('
    POLYGON ((
            0 0, 1185 0, 1185 100, 1400 315, 1620 315, 1620 1170, 1645 1170,
            1645 3550, 1500 3700, 1310 4010, 1025 4310, 700 4510, 300 4630, 0 4630, 0 0
    ))
')),
('BE2', ST_GeomFromText('
    POLYGON ((
            0 0, 1185 0, 1185 100, 1400 315, 1620 315, 1620 1170, 1645 1170,
            1645 3550, 1409 4216, 1324 4216, 700 4510, 300 4630, 0 4630, 0 0
    ))
')),
('BE3', ST_GeomFromText('
    POLYGON ((
            0 0, 1185 0, 1185 100, 1400 315, 1620 315, 1620 1170, 1645 1170,
            1645 3550, 1409 4218, 785 4680, 0 4680, 0 0
    ))
')),
('FR-3.3', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1525 3500, 1475 3700, 1350 3900, 1100 4100, 550 4350, 0 4350, 0 0
    ))
')),
('G1', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1425 3700, 1120 4010, 525 4310, 0 4310, 0 0
    ))
')),
('G2', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3530, 1470 3835, 785 4680, 0 4680, 0 0
    ))
')),
('GA', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1360 3880, 1090 4080, 545 4350, 0 4350, 0 0
    ))
')),
('GB', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1360 4110, 545 4350, 0 4350, 0 0
    ))
')),
('GB1', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1440 4210, 545 4350, 0 4350, 0 0
    ))
')),
('GB2', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1450 4350, 0 4350, 0 0
    ))
')),
('GC', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3550, 1540 4700, 0 4700, 0 0
    ))
'));

SELECT g_inner.gauge_name our_train, list(g_outer.gauge_name) possible_tracks
FROM gauge_shapes g_inner, gauge_shapes g_outer
WHERE true --g_outer.gauge_name = 'BE1' 
  AND ST_Covers(g_outer.geom, g_inner.geom)
GROUP BY our_train
ORDER BY length(possible_tracks) DESC;

SELECT g_outer.gauge_name our_tracks, list(g_inner.gauge_name) possible_trains
FROM gauge_shapes g_inner, gauge_shapes g_outer
WHERE true --g_outer.gauge_name = 'BE1' 
  AND ST_Covers(g_outer.geom, g_inner.geom)
GROUP BY our_tracks
ORDER BY length(possible_trains) DESC;

-- yeah, if i delete the bottom half of the train, it's much more sensible

DROP TABLE IF EXISTS gauge_shapes;
CREATE TABLE gauge_shapes (
    gauge_name VARCHAR,
    geom GEOMETRY
);


INSERT INTO gauge_shapes VALUES 
-- some liberties taken with the lower parts. NB: lots share G1 lower parts. all kinematic gauges.
-- this is mad but preview on https://wktmap.com/ with EPSG:3857
-- so, afaict, all belgian gauges are incompatible with international ones? they're both bigger and smaller
-- which seems implausible, especially given that the high speed line claims to be BE2 https://data-interop.era.europa.eu/describe#http%3A%2F%2Fdata.europa.eu%2F949%2FfunctionalInfrastructure%2Ftracks%2Fd5e686f1037c0ee60ea2f6576dab009107590528
-- maybe there's some issue with the bottom bit
('FIN1', ST_GeomFromText('
    POLYGON ((
            0 0, 865 0, 865 125, 1300 125, 1500 330, 1700 330, 1700 1250, 1800 1250,
            1800 3500, 1700 3500, 1700 4000, 1500 4600, 900 5300, 0 5300, 0 0
    ))
')),
('SEa', ST_GeomFromText('
    POLYGON ((
            0 50, 1330 50, 1430 150, 1430 305, 1510 385, 1635 385, 1635 1200, 1850 1200,
            1850 3780, 840 4790, 0 4790, 0 50
    ))
')),
('SEc', ST_GeomFromText('
    POLYGON ((
            0 50, 1330 50, 1430 150, 1430 305, 1510 385, 1635 385, 1635 770, 1860 770, 1980 1300, 1980 4990, 0 4990, 0 50
    ))
')),
('BE1', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3550, 1500 3700, 1310 4010, 1025 4310, 700 4510, 300 4630, 0 4630, 0 0
    ))
')),
('BE2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3550, 1409 4216, 1324 4216, 700 4510, 300 4630, 0 4630, 0 0
    ))
')),
('BE3', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3550, 1409 4218, 785 4680, 0 4680, 0 0
    ))
')),
('FR-3.3', ST_GeomFromText('
    POLYGON ((
            0 0, 1000 115, 1212 115, 1250 130, 1520 400, 1620 400, 1620 1170, 1645 1170, 
            1645 3250, 1525 3500, 1475 3700, 1350 3900, 1100 4100, 550 4350, 0 4350, 0 0
    ))
')),
('G1', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0,1645 3250, 1425 3700, 1120 4010, 525 4310, 0 4310, 0 0
    ))
')),
('G2', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3530, 1470 3835, 785 4680, 0 4680, 0 0
    ))
')),
('GA', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3250, 1360 3880, 1090 4080, 545 4350, 0 4350, 0 0
    ))
')),
('GB', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3250, 1360 4110, 545 4350, 0 4350, 0 0
    ))
')),
('GB1', ST_GeomFromText('
    POLYGON ((
            0 0 , 1645 0, 1645 3250, 1440 4210, 545 4350, 0 4350, 0 0
    ))
')),
('GB2', ST_GeomFromText('
    POLYGON ((
            0 0 , 1645 0, 1645 3250, 1450 4350, 0 4350, 0 0
    ))
')),
('GC', ST_GeomFromText('
    POLYGON ((
            0 0, 1645 0, 1645 3550, 1540 4700, 0 4700, 0 0
    ))
'));

SELECT g_inner.gauge_name our_train, list(g_outer.gauge_name) possible_tracks
FROM gauge_shapes g_inner, gauge_shapes g_outer
WHERE true --g_outer.gauge_name = 'BE1' 
  AND ST_Covers(g_outer.geom, g_inner.geom)
GROUP BY our_train
ORDER BY length(possible_tracks) DESC;

SELECT g_outer.gauge_name our_tracks, list(g_inner.gauge_name) possible_trains
FROM gauge_shapes g_inner, gauge_shapes g_outer
WHERE true --g_outer.gauge_name = 'BE1' 
  AND ST_Covers(g_outer.geom, g_inner.geom)
GROUP BY our_tracks
ORDER BY length(possible_trains) DESC;
