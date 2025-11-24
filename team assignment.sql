CRIME_DB.ANALYTICS.STG_LA_CRIME_SILVERCRIME_DB.ANALYTICS.STG_LA_CRIME_SILVER/* ============================================================
   0. DATABASE & SCHEMA
   ============================================================ */

CREATE DATABASE IF NOT EXISTS CRIME_DB;
CREATE SCHEMA   IF NOT EXISTS CRIME_DB.ANALYTICS;

USE DATABASE CRIME_DB;
USE SCHEMA   ANALYTICS;


/* ============================================================
   1. STAGING TABLE (from Databricks Silver)
   - If you already created & loaded this table, you can skip
     the CREATE OR REPLACE part and just keep the INSERTs later.
   ============================================================ */

CREATE OR REPLACE TABLE STG_LA_CRIME_SILVER (
    dr_no           STRING,
    date_rptd       TIMESTAMP_NTZ,
    date_occ        TIMESTAMP_NTZ,
    time_occ        STRING,
    area            STRING,
    area_name       STRING,
    rpt_dist_no     STRING,
    part_1_2        NUMBER,
    crm_cd          STRING,
    crm_cd_desc     STRING,
    mocodes         STRING,
    vict_age        NUMBER,
    vict_sex        STRING,
    vict_descent    STRING,
    premis_cd       NUMBER,
    premis_desc     STRING,
    weapon_used_cd  STRING,
    weapon_desc     STRING,
    status          STRING,
    status_desc     STRING,
    crm_cd_1        STRING,
    crm_cd_2        STRING,
    crm_cd_3        STRING,
    crm_cd_4        STRING,
    location        STRING,
    cross_street    STRING,
    lat             FLOAT,
    lon             FLOAT,
    year_occ        NUMBER,
    month_occ       NUMBER,
    quarter_occ     NUMBER,
    day_of_week     STRING,
    day_of_week_name STRING,
    is_weekend      STRING,
    time_occ_int    NUMBER,
    occ_hour        NUMBER,
    occ_minute      NUMBER,
    time_bucket     STRING,
    violent_flag    STRING,
    vict_age_grp    STRING,
    vict_sex_clean  STRING,
    geo_valid_flag  STRING
);

/* >>> At this point, load your data into STG_LA_CRIME_SILVER
       using COPY INTO or the UI, then continue.              */


/* ============================================================
   2. DIMENSION TABLES
   ============================================================ */

-- 2.1 Date Dimension (Type 1)
CREATE OR REPLACE TABLE dim_date (
    date_key        NUMBER(8) PRIMARY KEY,      -- YYYYMMDD
    full_date       DATE,
    year            NUMBER(4),
    quarter         NUMBER(1),
    month           NUMBER(2),
    month_name      STRING,
    day_of_month    NUMBER(2),
    day_of_week     STRING,
    day_of_week_name STRING,
    is_weekend      STRING
);

INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day_of_month,
    day_of_week,
    day_of_week_name,
    is_weekend
)
SELECT DISTINCT
    TO_NUMBER(TO_CHAR(date_occ::DATE, 'YYYYMMDD'))  AS date_key,
    date_occ::DATE                                  AS full_date,
    year_occ                                        AS year,
    quarter_occ                                     AS quarter,
    month_occ                                       AS month,
    TO_CHAR(date_occ::DATE, 'Mon')                  AS month_name,
    EXTRACT(DAY FROM date_occ)                      AS day_of_month,
    day_of_week,
    day_of_week_name,
    is_weekend
FROM STG_LA_CRIME_SILVER
WHERE date_occ IS NOT NULL;


-- 2.2 Location Dimension (Type 1)
CREATE OR REPLACE TABLE dim_location (
    location_key    INT AUTOINCREMENT PRIMARY KEY,
    area            STRING,
    area_name       STRING,
    rpt_dist_no     STRING,
    location        STRING,
    cross_street    STRING,
    lat             FLOAT,
    lon             FLOAT,
    geo_valid_flag  STRING
);

INSERT INTO dim_location (
    area, area_name, rpt_dist_no,
    location, cross_street,
    lat, lon,
    geo_valid_flag
)
SELECT DISTINCT
    area,
    area_name,
    rpt_dist_no,
    location,
    cross_street,
    lat,
    lon,
    geo_valid_flag
FROM STG_LA_CRIME_SILVER;


-- 2.3 Crime Dimension
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
    crm_cd, crm_cd_desc,
    part_1_2, violent_flag,
    crm_cd_1, crm_cd_2, crm_cd_3, crm_cd_4
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


-- 2.4 Victim Dimension
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


-- 2.5 Weapon Dimension
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
FROM STG_LA_CRIME_SILVER;


/* ============================================================
   3. FACT TABLE
   ============================================================ */

CREATE OR REPLACE TABLE fact_crime_incident (
    fact_key        INT AUTOINCREMENT PRIMARY KEY,
    dr_no           STRING,

    date_key        NUMBER(8),
    location_key    INT,
    crime_key       INT,
    victim_key      INT,
    weapon_key      INT,

    status          STRING,
    status_desc     STRING,

    time_occ        STRING,
    time_occ_int    NUMBER,
    occ_hour        NUMBER,
    occ_minute      NUMBER,
    time_bucket     STRING,

    geo_valid_flag  STRING,

    CONSTRAINT fk_fact_date
        FOREIGN KEY (date_key)     REFERENCES dim_date(date_key),
    CONSTRAINT fk_fact_location
        FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
    CONSTRAINT fk_fact_crime
        FOREIGN KEY (crime_key)    REFERENCES dim_crime(crime_key),
    CONSTRAINT fk_fact_victim
        FOREIGN KEY (victim_key)   REFERENCES dim_victim(victim_key),
    CONSTRAINT fk_fact_weapon
        FOREIGN KEY (weapon_key)   REFERENCES dim_weapon(weapon_key)
);

INSERT INTO fact_crime_incident (
    dr_no,
    date_key,
    location_key,
    crime_key,
    victim_key,
    weapon_key,
    status,
    status_desc,
    time_occ,
    time_occ_int,
    occ_hour,
    occ_minute,
    time_bucket,
    geo_valid_flag
)
SELECT
    s.dr_no,

    -- Date FK
    TO_NUMBER(TO_CHAR(s.date_occ::DATE, 'YYYYMMDD')) AS date_key,

    -- Location FK (area + RD is usually stable enough)
    dl.location_key,
    dc.crime_key,
    dv.victim_key,
    dw.weapon_key,

    s.status,
    s.status_desc,
    s.time_occ,
    s.time_occ_int,
    s.occ_hour,
    s.occ_minute,
    s.time_bucket,
    s.geo_valid_flag
FROM STG_LA_CRIME_SILVER s
JOIN dim_date     dd ON dd.date_key     = TO_NUMBER(TO_CHAR(s.date_occ::DATE, 'YYYYMMDD'))
JOIN dim_location dl ON dl.area         = s.area
                     AND dl.rpt_dist_no = s.rpt_dist_no
JOIN dim_crime    dc ON dc.crm_cd       = s.crm_cd
JOIN dim_victim   dv ON dv.vict_age     = s.vict_age
                    AND dv.vict_sex_clean = s.vict_sex_clean
                    AND dv.vict_descent   = s.vict_descent
LEFT JOIN dim_weapon  dw ON dw.weapon_used_cd = s.weapon_used_cd;
CRIME_DB



DROP TABLE IF EXISTS fact_crime_incident;
