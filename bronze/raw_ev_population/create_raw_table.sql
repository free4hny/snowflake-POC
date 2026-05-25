-- ============================================================
-- create_raw_table.sql
-- Purpose: Create raw Bronze table to store EV JSON as VARIANT
-- Run as: EV_DEMO_ENGINEER
-- ============================================================
-- NOTES:
--   VARIANT column stores entire JSON document as-is
--   No parsing, no type casting — exact copy of source
--   METADATA columns track which file and when it was loaded
--   This table is append-only (never update/delete in Bronze)
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.BRONZE;

CREATE TABLE IF NOT EXISTS RAW_EV_POPULATION (
    RAW_DATA           VARIANT        NOT NULL,
    SOURCE_FILE_NAME   VARCHAR        NOT NULL,
    SOURCE_FILE_ROW    NUMBER         NOT NULL,
    LOADED_AT          TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw EV population JSON data. Append-only, no transformations.';
