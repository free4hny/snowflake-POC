-- ============================================================
-- 06_create_json_file_format.sql
-- Purpose: Define reusable file formats for data loading
-- Run as: EV_DEMO_ENGINEER (or EV_DEMO_ADMIN)
-- ============================================================
-- NOTES:
--   File formats tell Snowflake how to parse incoming files.
--   Defined once in UTILITIES, reused across all COPY INTO commands.
--   STRIP_OUTER_ARRAY = TRUE handles JSON arrays at root level.
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.UTILITIES;

CREATE FILE FORMAT IF NOT EXISTS JSON_RAW_FORMAT
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = TRUE
    COMMENT = 'JSON format for raw EV population data. Strips outer array wrapper.';

-- Verify
SHOW FILE FORMATS IN SCHEMA EV_POPULATION_DB.UTILITIES;
