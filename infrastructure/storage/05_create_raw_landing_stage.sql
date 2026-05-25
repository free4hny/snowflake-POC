-- ============================================================
-- 05_create_raw_landing_stage.sql
-- Purpose: Create internal stage for uploading raw JSON files
-- Run as: EV_DEMO_ENGINEER (or EV_DEMO_ADMIN)
-- ============================================================
-- NOTES:
--   Internal stage = Snowflake-managed storage (no S3 needed)
--   Files are uploaded via PUT command
--   Organize files by source/date path for selective loading
--   Stage path structure:
--     @EV_RAW_STAGE/ev_population/YYYY/MM/filename.json
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.UTILITIES;

CREATE STAGE IF NOT EXISTS EV_RAW_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for raw source files. Organize by source/date path.';

-- Verify stage was created
SHOW STAGES IN SCHEMA EV_POPULATION_DB.UTILITIES;
