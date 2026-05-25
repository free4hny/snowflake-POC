-- ============================================================
-- put_files.sql
-- Purpose: Upload local JSON files to internal stage
-- Run as: EV_DEMO_ENGINEER
-- ============================================================
-- NOTES:
--   PUT uploads files from your local machine to the stage.
--   Organize by source and date for selective loading.
--   PUT auto-compresses files (gzip) to save storage.
--   Run this from SnowSQL or Snowflake CLI (not Snowsight UI).
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

-- Upload EV population JSON file to stage
-- Replace '/path/to/your/file.json' with actual local path
PUT file:///path/to/ev_population_data.json
    @EV_POPULATION_DB.UTILITIES.EV_RAW_STAGE/ev_population/
    AUTO_COMPRESS = TRUE
    OVERWRITE = FALSE;

-- Verify files in stage
LIST @EV_POPULATION_DB.UTILITIES.EV_RAW_STAGE/ev_population/;
