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
-- so. attempt 2. we ignore the bottom half of trains.

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
-- NB: i don't understand DE1, loads is missing. DE2 has a complex curve that i have approximated
-- GEE10 diagram is extremely blurry, may have misread
-- EBV1 and EBV2 were eyeballed from here
-- https://www.stuva.de/downloads/publikationen/pdf/SH_AK_TuSa_2011_screen.pdf 
--
-- DE1 is guessed(!) from here
-- https://www.dbcargo.com/rail-de-en/logistics-news/the-abc-of-freight-transport-loading-gauge-12978800
-- but NB it's unlabelled!
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
SELECT g_inner.gauge_name our_train, list(g_outer.gauge_name) possible_tracks
FROM gauge_shapes g_inner, gauge_shapes g_outer
WHERE true --g_outer.gauge_name = 'BE1' 
  AND ST_Covers(g_outer.geom, g_inner.geom)
GROUP BY our_train
ORDER BY length(possible_tracks) DESC
) TO 'train_to_possible_tracks.csv' (FORMAT 'csv');

COPY (
SELECT g_outer.gauge_name our_tracks, list(g_inner.gauge_name) possible_trains
FROM gauge_shapes g_inner, gauge_shapes g_outer
WHERE true --g_outer.gauge_name = 'BE1' 
  AND ST_Covers(g_outer.geom, g_inner.geom)
GROUP BY our_tracks
ORDER BY length(possible_trains) DESC
) TO 'track_to_possible_trains.csv' (FORMAT 'csv');
 
-- looking at what's missing
-- (scratch.csv is just the gauges and their counts from the sparql dump)
-- select label, n from 'scratch.csv' p
-- anti join (select distinct gauge_name from gauge_shapes) gs on gs.gauge_name = p.label;
-- lots of GI2 but that's in theory OK because it's just the undercarriage, so surely there's also an upper gauge



-- the biggest international train a track can take
-- i thought fr-3.3 was supposed to be appox GB, but according to this it's only G1
COPY (
select DISTINCT ON (the_track) gs.our_train our_train, the_track, universality from (
    SELECT g_inner.gauge_name our_train, g_outer.gauge_name the_track
    FROM gauge_shapes g_inner, gauge_shapes g_outer
    WHERE true --g_outer.gauge_name = 'BE1' 
      AND ST_Covers(g_outer.geom, g_inner.geom)
) gs
left join (
    SELECT g_inner.gauge_name our_train, length(list(g_outer.gauge_name)) universality
    FROM gauge_shapes g_inner, gauge_shapes g_outer
    WHERE true 
      AND g_inner.gauge_name in ('G1', 'G2', 'GB1', 'GB2', 'GA', 'GB', 'GC')
      AND ST_Covers(g_outer.geom, g_inner.geom)
    GROUP BY our_train
) gu on gu.our_train = gs.our_train
ORDER BY gu.universality ASC
) TO 'track_to_biggest_international_train.csv' (FORMAT 'csv');

-- todo: use this somewhere? nice h3 map?
select gauge_name, ST_Area(geom) area from gauge_shapes order by area desc;

-- debugging polygons - use with the python script
COPY (
    SELECT 
        gauge_name,
        ST_AsGeoJSON(geom) geometry
    FROM gauge_shapes
    WHERE gauge_name in ('FR-3.3', 'G1', 'GA', 'GB', 'GC')
) TO 'polygons.json' WITH (FORMAT JSON);

COPY (
    select distinct gp gauge_number, gpLabel gauge_label from 'out.parquet' order by gp asc
) TO 'gauge_labels.csv' (FORMAT 'csv');
