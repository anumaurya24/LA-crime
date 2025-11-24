# Databricks notebook source
import dlt
from pyspark.sql.functions import (
    col, to_timestamp, year, quarter, month, dayofweek,
    when
)


# COMMAND ----------

@dlt.table(
    name="la_crime_gold",
    comment="Gold layer for LA crime, enriched from silver for Snowflake model"
)
def la_crime_gold():
    df_silver = dlt.read("workspace.damg7370.la_crime_silver")

    df_gold = (
        df_silver
            .withColumn("date_rptd", to_timestamp("date_rptd"))
            .withColumn("date_occ",  to_timestamp("date_occ"))
            .withColumn("year_occ",    year("date_occ"))
            .withColumn("quarter_occ", quarter("date_occ"))
            .withColumn("month_occ",   month("date_occ"))
            .withColumn("day_of_week", dayofweek("date_occ"))
            .withColumn(
                "day_of_week_name",
                when(col("day_of_week") == 1, "Sun")
                .when(col("day_of_week") == 2, "Mon")
                .when(col("day_of_week") == 3, "Tue")
                .when(col("day_of_week") == 4, "Wed")
                .when(col("day_of_week") == 5, "Thu")
                .when(col("day_of_week") == 6, "Fri")
                .otherwise("Sat")
            )
            .withColumn(
                "is_weekend",
                when(col("day_of_week").isin(1, 7), "Y").otherwise("N")
            )
            .withColumn("time_occ_int", col("time_occ").cast("int"))
            .withColumn("occ_hour",     (col("time_occ_int") / 100).cast("int"))
            .withColumn("occ_minute",   (col("time_occ_int") % 100).cast("int"))
            .withColumn(
                "time_bucket",
                when(col("occ_hour").between(0, 5),  "Night")
                .when(col("occ_hour").between(6, 11), "Morning")
                .when(col("occ_hour").between(12, 17), "Afternoon")
                .otherwise("Evening")
            )
            .withColumn(
                "violent_flag",
                when(col("crm_cd_desc").rlike("ASSAULT|ROBBERY|HOMICIDE|RAPE"), "Y")
                .otherwise("N")
            )
            .withColumn(
                "vict_age_grp",
                when(col("vict_age") < 18, "Child")
                .when(col("vict_age").between(18, 24), "Youth")
                .when(col("vict_age").between(25, 64), "Adult")
                .otherwise("Senior")
            )
            .withColumn(
                "vict_sex_clean",
                when(col("vict_sex").isin("M", "F"), col("vict_sex"))
                .otherwise("X")
            )
    )

    return df_gold
