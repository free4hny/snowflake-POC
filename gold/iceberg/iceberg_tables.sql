-- ============================================================
-- iceberg_tables.sql
-- Purpose: Create Iceberg format tables for external engine interoperability
-- Run as: EV_DEMO_ADMIN
-- Prerequisite: GRANT CREATE ICEBERG TABLE ON SCHEMA GOLD TO ROLE EV_DEMO_ADMIN
-- ============================================================
-- WHY ICEBERG:
--   - Open table format (Apache Parquet underneath)
--   - Queryable by Spark, Trino, Presto, Databricks, Flink
--   - ACID transactions + time travel
--   - Schema evolution without rewriting data
--
-- WHY AT GOLD LAYER:
--   - Gold = business-ready, shared with external consumers
--   - External engines need clean, typed, aggregated data
--
-- SNOWFLAKE_MANAGED:
--   - Simplest setup (no S3/GCS/Azure configuration)
--   - For full external access, use a custom external volume on S3
--
-- REFRESH: Iceberg tables are static. To update:
--   INSERT OVERWRITE INTO ... SELECT * FROM source;
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

CREATE OR REPLACE ICEBERG TABLE EV_POPULATION_DB.GOLD.FACT_EV_REGISTRATIONS_ICE
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
AS
SELECT
    VIN, DOL_VEHICLE_ID, MAKE, MODEL, MODEL_YEAR, EV_TYPE,
    CAFV_ELIGIBILITY, ELECTRIC_RANGE, BASE_MSRP, CITY, COUNTY,
    STATE, ZIP_CODE, LEGISLATIVE_DISTRICT, ELECTRIC_UTILITY,
    CENSUS_TRACT, VEHICLE_LOCATION, EV_TYPE_SHORT, IS_CAFV_ELIGIBLE,
    REGISTERED_AT::TIMESTAMP_NTZ(6) AS REGISTERED_AT
FROM EV_POPULATION_DB.GOLD.FACT_EV_REGISTRATIONS;

CREATE OR REPLACE ICEBERG TABLE EV_POPULATION_DB.GOLD.DIM_CHARGING_STATIONS_ICE
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
AS
SELECT
    STATION_ID, STATION_NAME, CITY, COUNTY, STATE, ZIP_CODE,
    CONNECTOR_TYPE, POWER_LEVEL_KW, NETWORK, NUM_PORTS,
    STATION_STATUS, LATITUDE, LONGITUDE, CHARGING_TIER,
    LAST_UPDATED_AT::TIMESTAMP_NTZ(6) AS LAST_UPDATED_AT
FROM EV_POPULATION_DB.GOLD.DIM_CHARGING_STATIONS;

SHOW ICEBERG TABLES IN SCHEMA EV_POPULATION_DB.GOLD;
