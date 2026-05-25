-- ============================================================
-- dim_charging_stations.sql
-- Purpose: Dimension table — charging station lookup with tier classification
-- Method: Dynamic Table on SILVER.PG_CLEAN_CHARGING_STATIONS
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

CREATE OR REPLACE DYNAMIC TABLE EV_POPULATION_DB.GOLD.DIM_CHARGING_STATIONS
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_DEMO_WH
AS
SELECT
    STATION_ID,
    STATION_NAME,
    CITY,
    COUNTY,
    STATE,
    ZIP_CODE,
    CONNECTOR_TYPE,
    POWER_LEVEL_KW,
    NETWORK,
    NUM_PORTS,
    STATION_STATUS,
    LATITUDE,
    LONGITUDE,
    CASE
        WHEN POWER_LEVEL_KW >= 150 THEN 'DC Fast Charging'
        WHEN POWER_LEVEL_KW >= 20 THEN 'Level 2 Fast'
        ELSE 'Level 2 Standard'
    END AS CHARGING_TIER,
    MERGED_AT AS LAST_UPDATED_AT
FROM EV_POPULATION_DB.SILVER.PG_CLEAN_CHARGING_STATIONS;
