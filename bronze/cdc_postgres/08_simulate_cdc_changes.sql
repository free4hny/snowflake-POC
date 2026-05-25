-- ============================================================
-- 08_simulate_cdc_changes.sql
-- Purpose: Simulate PostgreSQL CDC events for demo/testing
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- Run these statements to simulate what happens when data changes
-- in PostgreSQL. The Stream will capture these, and the Task
-- (when resumed) will MERGE them into PG_BRONZE.
--
-- BEFORE RUNNING: Make sure the task is resumed:
--   ALTER TASK EV_POPULATION_DB.PG_RAW_SOURCE.PG_TSK_MERGE_CHARGING_STATIONS RESUME;
--
-- AFTER TESTING: Suspend the task to save credits:
--   ALTER TASK EV_POPULATION_DB.PG_RAW_SOURCE.PG_TSK_MERGE_CHARGING_STATIONS SUSPEND;
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.PG_RAW_SOURCE;

-- ============================================================
-- SIMULATE INSERT: New charging station added
-- ============================================================
INSERT INTO PG_RAW_CHARGING_STATIONS
    (STATION_ID, STATION_NAME, CITY, COUNTY, STATE, ZIP_CODE, CONNECTOR_TYPE, POWER_LEVEL_KW, NETWORK, NUM_PORTS, LATITUDE, LONGITUDE, LAST_UPDATED)
VALUES
    (17, 'ChargePoint Express - Federal Way', 'Federal Way', 'King', 'WA', '98003', 'CCS', 62, 'ChargePoint', 4, 47.3223, -122.3126, CURRENT_TIMESTAMP());

-- ============================================================
-- SIMULATE UPDATE: Station upgraded power level
-- ============================================================
UPDATE PG_RAW_CHARGING_STATIONS
SET POWER_LEVEL_KW = 350, LAST_UPDATED = CURRENT_TIMESTAMP()
WHERE STATION_ID = 3;

-- ============================================================
-- SIMULATE DELETE: Station decommissioned
-- ============================================================
DELETE FROM PG_RAW_CHARGING_STATIONS
WHERE STATION_ID = 7;

-- ============================================================
-- VERIFY: Check stream captured the changes
-- ============================================================
SELECT STATION_ID, STATION_NAME, METADATA$ACTION AS ACTION, METADATA$ISUPDATE AS IS_UPDATE
FROM PG_STM_CHARGING_STATIONS;

-- ============================================================
-- VERIFY: After task runs (~1 min), check PG_BRONZE
-- ============================================================
-- SELECT STATION_ID, STATION_NAME, POWER_LEVEL_KW, IS_DELETED, MERGED_AT
-- FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
-- WHERE STATION_ID IN (3, 7, 17);
