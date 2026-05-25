-- ============================================================
-- snowpipe_auto_ingest.sql
-- Purpose: Automated ingestion of new JSON files via Snowpipe
-- Run as: EV_DEMO_ADMIN
-- Prerequisite: GRANT CREATE PIPE, CREATE STREAM, CREATE TASK ON SCHEMA BRONZE
-- ============================================================
-- FLOW:
--   1. New JSON file uploaded to @EV_RAW_STAGE/ev_population/
--   2. Snowpipe (AUTO_INGEST) loads entire file as 1 VARIANT row → staging table
--   3. Stream detects new row in staging
--   4. Task fires FLATTEN → inserts individual vehicle rows into RAW_EV_POPULATION
--
-- COST:
--   Snowpipe: ~0.06 credits/file (serverless)
--   Task FLATTEN: ~0.02 credits/file (XS warehouse, ~60s)
--   Total: ~0.08 credits per file
--
-- NOTE: Snowpipe tracks file names. Same-name files are skipped.
--   Always upload with unique names (e.g. ev_data_2024_06.json)
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

-- STEP 1: Staging table (Snowpipe lands whole files here)
CREATE TABLE IF NOT EXISTS EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION_STAGING (
    RAW_FILE         VARIANT        NOT NULL,
    SOURCE_FILE_NAME VARCHAR        NOT NULL,
    LOADED_AT        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()
)
CHANGE_TRACKING = TRUE
COMMENT = 'Snowpipe landing: 1 row per file. Stream+Task FLATTEN into RAW_EV_POPULATION.';

-- STEP 2: Snowpipe (auto-loads new files, serverless)
CREATE OR REPLACE PIPE EV_POPULATION_DB.BRONZE.EV_AUTO_INGEST_PIPE
    AUTO_INGEST = TRUE
    COMMENT = 'Auto-loads new JSON files from EV_RAW_STAGE into staging table as VARIANT'
AS
COPY INTO EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION_STAGING (RAW_FILE, SOURCE_FILE_NAME, LOADED_AT)
FROM (
    SELECT $1, METADATA$FILENAME, METADATA$START_SCAN_TIME
    FROM @EV_POPULATION_DB.UTILITIES.EV_RAW_STAGE/ev_population/
)
FILE_FORMAT = 'EV_POPULATION_DB.UTILITIES.JSON_RAW_FORMAT';

-- STEP 3: Stream (detects new rows in staging — FREE)
CREATE OR REPLACE STREAM EV_POPULATION_DB.BRONZE.STM_RAW_EV_STAGING
    ON TABLE EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION_STAGING
    COMMENT = 'Captures new file loads from Snowpipe. Triggers FLATTEN task.';

-- STEP 4: Task (FLATTEN + INSERT, fires only when stream has data)
CREATE OR REPLACE TASK EV_POPULATION_DB.BRONZE.TSK_FLATTEN_EV_STAGING
    WAREHOUSE = EV_DEMO_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('EV_POPULATION_DB.BRONZE.STM_RAW_EV_STAGING')
AS
INSERT INTO EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION (RAW_DATA, SOURCE_FILE_NAME, SOURCE_FILE_ROW, LOADED_AT)
SELECT
    f.value,
    stg.SOURCE_FILE_NAME,
    f.index,
    CURRENT_TIMESTAMP()
FROM EV_POPULATION_DB.BRONZE.STM_RAW_EV_STAGING stg,
    LATERAL FLATTEN(input => stg.RAW_FILE:data) f
WHERE stg.METADATA$ACTION = 'INSERT';

-- Task created SUSPENDED. Resume when ready:
-- ALTER TASK EV_POPULATION_DB.BRONZE.TSK_FLATTEN_EV_STAGING RESUME;

-- ============================================================
-- TO TEST: Upload a new file with unique name, then:
--   ALTER TASK EV_POPULATION_DB.BRONZE.TSK_FLATTEN_EV_STAGING RESUME;
--   -- Wait ~2 min --
--   SELECT COUNT(*) FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION;
--   ALTER TASK EV_POPULATION_DB.BRONZE.TSK_FLATTEN_EV_STAGING SUSPEND;
-- ============================================================
