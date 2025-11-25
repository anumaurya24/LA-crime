USE DATABASE CRIME_DB;
USE SCHEMA ANALYTICS;
-- OPTIONAL: clear old dims/fact if you want a clean rebuild
TRUNCATE TABLE IF EXISTS dim_date;
TRUNCATE TABLE IF EXISTS dim_time;
TRUNCATE TABLE IF EXISTS dim_location;
TRUNCATE TABLE IF EXISTS dim_crime;
TRUNCATE TABLE IF EXISTS dim_victim;
TRUNCATE TABLE IF EXISTS dim_weapon;
TRUNCATE TABLE IF EXISTS dim_premise;
TRUNCATE TABLE IF EXISTS dim_status;
TRUNCATE TABLE IF EXISTS dim_mocode;
TRUNCATE TABLE IF EXISTS fact_crime_incident;

---------------------------------------------------------------
-- 2.1 DATE DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_date (
    date_key         NUMBER(8) PRIMARY KEY,
    full_date        DATE,
    year             NUMBER,
    month            NUMBER,
    quarter          NUMBER,
    month_name       STRING,
    day_of_month     NUMBER,
    day_of_week      STRING,
    day_of_week_name STRING,
    is_weekend       STRING
);

INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    month,
    quarter,
    month_name,
    day_of_month,
    day_of_week,
    day_of_week_name,
    is_weekend
)
SELECT DISTINCT
    TO_NUMBER(TO_CHAR(date_occ::DATE, 'YYYYMMDD')) AS date_key,
    date_occ::DATE                                  AS full_date,
    year_occ                                        AS year,
    month_occ                                       AS month,
    quarter_occ                                     AS quarter,
    TO_CHAR(date_occ::DATE, 'Mon')                  AS month_name,
    EXTRACT(DAY FROM date_occ)                      AS day_of_month,
    day_of_week,
    day_of_week_name,
    is_weekend
FROM STG_LA_CRIME_SILVER
WHERE date_occ IS NOT NULL;

---------------------------------------------------------------
-- 2.2 TIME DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_time (
    time_key      INT AUTOINCREMENT PRIMARY KEY,
    time_occ      STRING,
    time_occ_int  NUMBER,
    occ_hour      NUMBER,
    occ_minute    NUMBER,
    time_bucket   STRING
);

INSERT INTO dim_time (
    time_occ,
    time_occ_int,
    occ_hour,
    occ_minute,
    time_bucket
)
SELECT DISTINCT
    time_occ,
    time_occ_int,
    occ_hour,
    occ_minute,
    time_bucket
FROM STG_LA_CRIME_SILVER;

---------------------------------------------------------------
-- 2.3 LOCATION DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_location (
    location_key   INT AUTOINCREMENT PRIMARY KEY,
    area           STRING,
    rpt_dist_no    STRING,
    area_name      STRING,
    location       STRING,
    cross_street   STRING,
    lat            FLOAT,
    lon            FLOAT,
    geo_valid_flag STRING
);

INSERT INTO dim_location (
    area,
    rpt_dist_no,
    area_name,
    location,
    cross_street,
    lat,
    lon,
    geo_valid_flag
)
SELECT
    area,
    rpt_dist_no,
    ANY_VALUE(area_name)      AS area_name,
    ANY_VALUE(location)       AS location,
    ANY_VALUE(cross_street)   AS cross_street,
    AVG(lat)                  AS lat,
    AVG(lon)                  AS lon,
    ANY_VALUE(geo_valid_flag) AS geo_valid_flag
FROM STG_LA_CRIME_SILVER
GROUP BY
    area,
    rpt_dist_no;

---------------------------------------------------------------
-- 2.4 CRIME DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_crime (
    crime_key       INT AUTOINCREMENT PRIMARY KEY,
    crm_cd          STRING,
    crm_cd_desc     STRING,
    part_1_2        NUMBER,
    violent_flag    STRING,
    crm_cd_1        STRING,
    crm_cd_2        STRING,
    crm_cd_3        STRING,
    crm_cd_4        STRING
);

INSERT INTO dim_crime (
    crm_cd,
    crm_cd_desc,
    part_1_2,
    violent_flag,
    crm_cd_1,
    crm_cd_2,
    crm_cd_3,
    crm_cd_4
)
SELECT DISTINCT
    crm_cd,
    crm_cd_desc,
    part_1_2,
    violent_flag,
    crm_cd_1,
    crm_cd_2,
    crm_cd_3,
    crm_cd_4
FROM STG_LA_CRIME_SILVER;

---------------------------------------------------------------
-- 2.5 VICTIM DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_victim (
    victim_key      INT AUTOINCREMENT PRIMARY KEY,
    vict_age        NUMBER,
    vict_age_grp    STRING,
    vict_sex        STRING,
    vict_sex_clean  STRING,
    vict_descent    STRING
);

INSERT INTO dim_victim (
    vict_age,
    vict_age_grp,
    vict_sex,
    vict_sex_clean,
    vict_descent
)
SELECT DISTINCT
    vict_age,
    vict_age_grp,
    vict_sex,
    vict_sex_clean,
    vict_descent
FROM STG_LA_CRIME_SILVER;

---------------------------------------------------------------
-- 2.6 WEAPON DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_weapon (
    weapon_key      INT AUTOINCREMENT PRIMARY KEY,
    weapon_used_cd  STRING,
    weapon_desc     STRING
);

INSERT INTO dim_weapon (
    weapon_used_cd,
    weapon_desc
)
SELECT DISTINCT
    weapon_used_cd,
    weapon_desc
FROM STG_LA_CRIME_SILVER
WHERE weapon_used_cd IS NOT NULL;

INSERT INTO dim_weapon (weapon_used_cd, weapon_desc)
SELECT 'UNKNOWN', 'Unknown / No weapon'
WHERE NOT EXISTS (SELECT 1 FROM dim_weapon WHERE weapon_used_cd = 'UNKNOWN');

---------------------------------------------------------------
-- 2.7 PREMISE DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_premise (
    premise_key   INT AUTOINCREMENT PRIMARY KEY,
    premis_cd     NUMBER,
    premis_desc   STRING
);

INSERT INTO dim_premise (
    premis_cd,
    premis_desc
)
SELECT DISTINCT
    premis_cd,
    premis_desc
FROM STG_LA_CRIME_SILVER
WHERE premis_cd IS NOT NULL;

---------------------------------------------------------------
-- 2.8 STATUS DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_status (
    status_key   INT AUTOINCREMENT PRIMARY KEY,
    status       STRING,
    status_desc  STRING
);

INSERT INTO dim_status (
    status,
    status_desc
)
SELECT DISTINCT
    status,
    status_desc
FROM STG_LA_CRIME_SILVER
WHERE status IS NOT NULL;

---------------------------------------------------------------
-- 2.9 MOCODE DIM
---------------------------------------------------------------
CREATE OR REPLACE TABLE dim_mocode (
    mocode_key   INT AUTOINCREMENT PRIMARY KEY,
    mocodes      STRING
);

INSERT INTO dim_mocode (mocodes)
SELECT DISTINCT
    mocodes
FROM STG_LA_CRIME_SILVER
WHERE mocodes IS NOT NULL;

CREATE OR REPLACE TABLE fact_crime_incident (
    fact_key       INT AUTOINCREMENT PRIMARY KEY,
    dr_no          STRING,

    date_key       NUMBER(8),
    time_key       INT,
    location_key   INT,
    crime_key      INT,
    victim_key     INT,
    weapon_key     INT,
    premise_key    INT,
    status_key     INT,
    mocode_key     INT,

    geo_valid_flag STRING
);

INSERT INTO fact_crime_incident (
    dr_no,
    date_key,
    time_key,
    location_key,
    crime_key,
    victim_key,
    weapon_key,
    premise_key,
    status_key,
    mocode_key,
    geo_valid_flag
)
SELECT
    s.dr_no,
    TO_NUMBER(TO_CHAR(s.date_occ::DATE, 'YYYYMMDD')) AS date_key,
    dt.time_key,
    dl.location_key,
    dc.crime_key,
    dv.victim_key,
    COALESCE(
        dw.weapon_key,
        (SELECT weapon_key FROM dim_weapon WHERE weapon_used_cd = 'UNKNOWN')
    ),
    dp.premise_key,
    ds.status_key,
    dm.mocode_key,
    s.geo_valid_flag
FROM STG_LA_CRIME_SILVER s
JOIN dim_date     dd ON dd.date_key       = TO_NUMBER(TO_CHAR(s.date_occ::DATE, 'YYYYMMDD'))
JOIN dim_time     dt ON dt.time_occ_int   = s.time_occ_int
JOIN dim_location dl ON dl.area           = s.area
                     AND dl.rpt_dist_no   = s.rpt_dist_no
JOIN dim_crime    dc ON dc.crm_cd         = s.crm_cd
JOIN dim_victim   dv ON dv.vict_age       = s.vict_age
                    AND dv.vict_sex_clean = s.vict_sex_clean
                    AND dv.vict_descent   = s.vict_descent
LEFT JOIN dim_weapon  dw ON dw.weapon_used_cd = s.weapon_used_cd
LEFT JOIN dim_premise dp ON dp.premis_cd      = s.premis_cd
LEFT JOIN dim_status  ds ON ds.status         = s.status
LEFT JOIN dim_mocode  dm ON dm.mocodes        = s.mocodes;


SELECT COUNT(*) FROM STG_LA_CRIME_SILVER;
SELECT COUNT(*) FROM dim_date;
SELECT COUNT(*) FROM dim_time;
SELECT COUNT(*) FROM dim_location;
SELECT COUNT(*) FROM dim_crime;
SELECT COUNT(*) FROM dim_victim;
SELECT COUNT(*) FROM dim_weapon;
SELECT COUNT(*) FROM fact_crime_incident;

SELECT * FROM fact_crime_incident LIMIT 20;
