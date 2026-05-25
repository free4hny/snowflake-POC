-- ============================================================
-- pg_tsk_refresh_silver.sql
-- Purpose: Auto-trigger Silver refresh when PG_BRONZE changes
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- FLOW:
--   PG_BRONZE.PG_CHARGING_STATIONS changes (via CDC merge)
--       │
--       ▼  Stream detects change (FREE)
--   PG_STM_SILVER_TRIGGER has data
--       │
--       ▼  Task fires (only when stream has data)
--   SP_REFRESH_PG_CLEAN_CHARGING_STATIONS() rebuilds Silver table
--
-- COST: Zero when no changes. ~0.02 credits per refresh.
--
-- NOTE: dbt tests still run separately (dbt test --project-dir ...)
--       This automates the TRANSFORM. DQ validation remains manual/scheduled.
--
-- TO RESUME:  ALTER TASK EV_POPULATION_DB.PG_BRONZE.PG_TSK_REFRESH_SILVER RESUME;
-- TO SUSPEND: ALTER TASK EV_POPULATION_DB.PG_BRONZE.PG_TSK_REFRESH_SILVER SUSPEND;
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

-- Stream on PG_BRONZE (detects CDC changes)
CREATE OR REPLACE STREAM EV_POPULATION_DB.PG_BRONZE.PG_STM_SILVER_TRIGGER
    ON TABLE EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
    COMMENT = 'Detects changes in PG_BRONZE. Triggers dbt run for Silver layer.';

-- Procedure that rebuilds Silver (mirrors dbt model logic)
CREATE OR REPLACE PROCEDURE EV_POPULATION_DB.SILVER.SP_REFRESH_PG_CLEAN_CHARGING_STATIONS()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    CREATE OR REPLACE TABLE EV_POPULATION_DB.SILVER.PG_CLEAN_CHARGING_STATIONS AS
    SELECT
        STATION_ID,
        TRIM(STATION_NAME)              AS STATION_NAME,
        TRIM(INITCAP(CITY))             AS CITY,
        TRIM(UPPER(COUNTY))             AS COUNTY,
        UPPER(STATE)                    AS STATE,
        TRIM(ZIP_CODE)                  AS ZIP_CODE,
        UPPER(CONNECTOR_TYPE)           AS CONNECTOR_TYPE,
        POWER_LEVEL_KW,
        TRIM(NETWORK)                   AS NETWORK,
        NUM_PORTS,
        UPPER(STATUS)                   AS STATION_STATUS,
        LATITUDE,
        LONGITUDE,
        LAST_UPDATED,
        MERGED_AT
    FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
    WHERE IS_DELETED = FALSE
      AND STATION_ID IS NOT NULL
      AND POWER_LEVEL_KW BETWEEN 1 AND 500;

    LET row_count NUMBER := (SELECT COUNT(*) FROM EV_POPULATION_DB.SILVER.PG_CLEAN_CHARGING_STATIONS);
    RETURN 'Silver PG_CLEAN_CHARGING_STATIONS refreshed. Rows: ' || :row_count;
END;

-- Task: fires only when PG_BRONZE has new/changed data
CREATE OR REPLACE TASK EV_POPULATION_DB.PG_BRONZE.PG_TSK_REFRESH_SILVER
    WAREHOUSE = EV_DEMO_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('EV_POPULATION_DB.PG_BRONZE.PG_STM_SILVER_TRIGGER')
AS
    CALL EV_POPULATION_DB.SILVER.SP_REFRESH_PG_CLEAN_CHARGING_STATIONS();

-- Task created SUSPENDED. Resume when ready:
-- ALTER TASK EV_POPULATION_DB.PG_BRONZE.PG_TSK_REFRESH_SILVER RESUME;
