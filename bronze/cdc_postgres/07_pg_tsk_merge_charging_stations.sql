-- ============================================================
-- 07_pg_tsk_merge_charging_stations.sql
-- Purpose: Task that merges CDC changes from stream into PG_BRONZE
-- Run as: EV_DEMO_ADMIN
-- Prerequisite: GRANT EXECUTE TASK ON ACCOUNT TO ROLE EV_DEMO_ADMIN
-- ============================================================
-- COST SAFETY:
--   WHEN SYSTEM$STREAM_HAS_DATA means:
--   - No data in stream = task skips = zero warehouse cost
--   - Data exists = warehouse wakes, merges, auto-suspends
--   SCHEDULE = '1 MINUTE' checks every minute (check itself is free)
--
-- MERGE LOGIC:
--   INSERT (new row)    → INSERT into PG_BRONZE
--   UPDATE (changed)    → UPDATE existing row + reset IS_DELETED
--   DELETE (removed)    → Soft-delete (IS_DELETED = TRUE)
--
-- TO RESUME:  ALTER TASK ... RESUME;
-- TO SUSPEND: ALTER TASK ... SUSPEND;
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.PG_RAW_SOURCE;

CREATE OR REPLACE TASK PG_TSK_MERGE_CHARGING_STATIONS
    WAREHOUSE = EV_DEMO_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('EV_POPULATION_DB.PG_RAW_SOURCE.PG_STM_CHARGING_STATIONS')
AS
MERGE INTO EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS AS tgt
USING (
    SELECT
        STATION_ID, STATION_NAME, CITY, COUNTY, STATE, ZIP_CODE,
        CONNECTOR_TYPE, POWER_LEVEL_KW, NETWORK, NUM_PORTS, STATUS,
        LATITUDE, LONGITUDE, LAST_UPDATED,
        METADATA$ACTION AS CDC_ACTION,
        METADATA$ISUPDATE AS IS_UPDATE
    FROM EV_POPULATION_DB.PG_RAW_SOURCE.PG_STM_CHARGING_STATIONS
) AS src
ON tgt.STATION_ID = src.STATION_ID
WHEN MATCHED AND src.CDC_ACTION = 'DELETE' AND src.IS_UPDATE = FALSE THEN
    UPDATE SET tgt.IS_DELETED = TRUE, tgt.MERGED_AT = CURRENT_TIMESTAMP()
WHEN MATCHED AND src.CDC_ACTION = 'INSERT' AND src.IS_UPDATE = TRUE THEN
    UPDATE SET
        tgt.STATION_NAME = src.STATION_NAME,
        tgt.CITY = src.CITY,
        tgt.COUNTY = src.COUNTY,
        tgt.STATE = src.STATE,
        tgt.ZIP_CODE = src.ZIP_CODE,
        tgt.CONNECTOR_TYPE = src.CONNECTOR_TYPE,
        tgt.POWER_LEVEL_KW = src.POWER_LEVEL_KW,
        tgt.NETWORK = src.NETWORK,
        tgt.NUM_PORTS = src.NUM_PORTS,
        tgt.STATUS = src.STATUS,
        tgt.LATITUDE = src.LATITUDE,
        tgt.LONGITUDE = src.LONGITUDE,
        tgt.LAST_UPDATED = src.LAST_UPDATED,
        tgt.IS_DELETED = FALSE,
        tgt.MERGED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED AND src.CDC_ACTION = 'INSERT' THEN
    INSERT (STATION_ID, STATION_NAME, CITY, COUNTY, STATE, ZIP_CODE,
            CONNECTOR_TYPE, POWER_LEVEL_KW, NETWORK, NUM_PORTS, STATUS,
            LATITUDE, LONGITUDE, LAST_UPDATED, MERGED_AT, IS_DELETED)
    VALUES (src.STATION_ID, src.STATION_NAME, src.CITY, src.COUNTY, src.STATE, src.ZIP_CODE,
            src.CONNECTOR_TYPE, src.POWER_LEVEL_KW, src.NETWORK, src.NUM_PORTS, src.STATUS,
            src.LATITUDE, src.LONGITUDE, src.LAST_UPDATED, CURRENT_TIMESTAMP(), FALSE);

-- Task is created SUSPENDED by default. Resume when ready:
-- ALTER TASK PG_TSK_MERGE_CHARGING_STATIONS RESUME;
