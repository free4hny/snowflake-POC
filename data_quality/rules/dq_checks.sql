-- ============================================================
-- dq_checks.sql
-- Purpose: Master DQ runner — calls all layer-specific DQ procedures
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- Runs all DQ checks across all layers. Call individual procedures
-- for targeted checks, or this script for full sweep.
--
-- USAGE:
--   Run this script to execute all Bronze DQ checks.
--   Results: SELECT * FROM EV_POPULATION_DB.AUDIT.AUDIT_DQ_RESULTS;
--   Failures: SELECT * FROM EV_POPULATION_DB.AUDIT.DLQ_BRONZE;
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

-- Bronze EV Population (JSON source)
CALL EV_POPULATION_DB.AUDIT.SP_DQ_CHECK_BRONZE_EV();

-- Bronze Charging Stations (PostgreSQL CDC source)
CALL EV_POPULATION_DB.AUDIT.SP_DQ_CHECK_BRONZE_PG();

-- Silver EV Population (Dynamic Table)
CALL EV_POPULATION_DB.AUDIT.SP_DQ_CHECK_SILVER_EV();

-- Silver Charging Stations: run dbt test separately
-- dbt test --project-dir /silver/dbt_charging_stations

-- View results
SELECT CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_FAILED, STATUS, CHECKED_AT
FROM EV_POPULATION_DB.AUDIT.AUDIT_DQ_RESULTS
ORDER BY CHECKED_AT DESC
LIMIT 30;

-- View any DLQ entries
SELECT * FROM EV_POPULATION_DB.AUDIT.DLQ_BRONZE WHERE STATUS = 'QUARANTINED';
SELECT * FROM EV_POPULATION_DB.AUDIT.DLQ_SILVER WHERE STATUS = 'QUARANTINED';
