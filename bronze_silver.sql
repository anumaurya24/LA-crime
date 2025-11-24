-- Databricks notebook source
USE CATALOG workspace;
USE SCHEMA damg7370;

-- COMMAND ----------

CREATE OR REFRESH STREAMING LIVE TABLE la_crime_bronze
COMMENT "Raw LA Crime CSV with cleaned column names."
TBLPROPERTIES ("quality" = "bronze") AS
SELECT
  DR_NO          AS dr_no,
  `Date Rptd`    AS date_rptd,
  `DATE OCC`     AS date_occ,
  `TIME OCC`     AS time_occ,
  AREA           AS area,
  `AREA NAME`    AS area_name,
  `Rpt Dist No`  AS rpt_dist_no,
  `Part 1-2`     AS part_1_2,
  `Crm Cd`       AS crm_cd,
  `Crm Cd Desc`  AS crm_cd_desc,
  Mocodes        AS mocodes,
  `Vict Age`     AS vict_age,
  `Vict Sex`     AS vict_sex,
  `Vict Descent` AS vict_descent,
  `Premis Cd`    AS premis_cd,
  `Premis Desc`  AS premis_desc,
  `Weapon Used Cd` AS weapon_used_cd,
  `Weapon Desc`    AS weapon_desc,
  Status           AS status,
  `Status Desc`    AS status_desc,
  `Crm Cd 1`       AS crm_cd_1,
  `Crm Cd 2`       AS crm_cd_2,
  `Crm Cd 3`       AS crm_cd_3,
  `Crm Cd 4`       AS crm_cd_4,
  LOCATION         AS location,
  `Cross Street`   AS cross_street,
  LAT              AS lat,
  LON              AS lon
FROM cloud_files(
  '/Volumes/workspace/damg7370/lacrime/',  --
  'csv',
  map(
    'header', 'true',
    'cloudFiles.inferColumnTypes', 'true'
  )
);

-- COMMAND ----------

CREATE OR REFRESH STREAMING LIVE TABLE la_crime_silver
COMMENT "Silver layer with cleaned, typed, enriched fields."
TBLPROPERTIES ("quality" = "silver") AS
SELECT
  dr_no,

  -- Clean & parse reporting date
  coalesce(
    to_timestamp(trim(date_rptd), 'yyyy MMM dd hh:mm:ss a'),
    to_timestamp(trim(date_rptd))
  ) AS date_rptd,

  -- Clean & parse occurrence date
  coalesce(
    to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
    to_timestamp(trim(date_occ))
  ) AS date_occ,

  time_occ,
  area,
  area_name,
  rpt_dist_no,
  part_1_2,
  crm_cd,
  crm_cd_desc,
  mocodes,
  cast(vict_age as int)      as vict_age,
  vict_sex,
  vict_descent,
  premis_cd,
  premis_desc,
  weapon_used_cd,
  weapon_desc,
  status,
  status_desc,
  crm_cd_1,
  crm_cd_2,
  crm_cd_3,
  crm_cd_4,
  location,
  cross_street,
  cast(lat as double)        as lat,
  cast(lon as double)        as lon,

  -- ===== DATE DERIVATIONS =====
  year(
    coalesce(to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
             to_timestamp(trim(date_occ)))
  ) as year_occ,

  month(
    coalesce(to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
             to_timestamp(trim(date_occ)))
  ) as month_occ,

  quarter(
    coalesce(to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
             to_timestamp(trim(date_occ)))
  ) as quarter_occ,

  date_format(
    coalesce(to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
             to_timestamp(trim(date_occ))),
    'E'
  ) as day_of_week,

  date_format(
    coalesce(to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
             to_timestamp(trim(date_occ))),
    'EEEE'
  ) as day_of_week_name,

  case
    when date_format(
      coalesce(to_timestamp(trim(date_occ), 'yyyy MMM dd hh:mm:ss a'),
               to_timestamp(trim(date_occ))),
      'E'
    ) in ('Sat','Sun') then 'Y'
    else 'N'
  end as is_weekend,

  -- ===== TIME DERIVATIONS =====
  cast(time_occ as int)                   as time_occ_int,
  cast(cast(time_occ as int) / 100 as int) as occ_hour,
  cast(cast(time_occ as int) % 100 as int) as occ_minute,
  lpad(cast(cast(time_occ as int) / 100 as string), 2, '0') || ':00' as time_bucket,

  -- ===== BUSINESS FLAGS =====
  case when part_1_2 = 1 then 'Y' else 'N' end as violent_flag,

  case
    when cast(vict_age as int) < 18 then 'Juvenile'
    when cast(vict_age as int) between 18 and 30 then '18-30'
    when cast(vict_age as int) between 31 and 50 then '31-50'
    when cast(vict_age as int) > 50 then '51+'
    else 'Unknown'
  end as vict_age_grp,

  case
    when vict_sex in ('M','F','X') then vict_sex
    else 'X'
  end as vict_sex_clean,

  -- ===== GEO VALIDITY FLAG =====
  case
    when cast(lat as double) between 33.6 and 34.5
     and cast(lon as double) between -118.8 and -118.0
    then 'Y' else 'N'
  end as geo_valid_flag

FROM STREAM(LIVE.la_crime_bronze)
WHERE dr_no IS NOT NULL
  AND trim(date_occ) != '';
