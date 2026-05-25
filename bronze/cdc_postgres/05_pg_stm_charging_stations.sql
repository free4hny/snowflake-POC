-- ============================================================
-- 05_pg_stm_charging_stations.sql
-- Purpose: Create stream to capture CDC changes on raw table
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- Streams track INSERT/UPDATE/DELETE at zero compute cost.
-- SHOW_INITIAL_ROWS = TRUE captures existing data as initial INSERTs.
-- Stream columns available in queries:
--   METADATA$ACTION    = 'INSERT' or 'DELETE'
--   METADATA$ISUPDATE  = TRUE if this is part of an UPDATE
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.PG_RAW_SOURCE;

CREATE OR REPLACE STREAM PG_STM_CHARGING_STATIONS
    ON TABLE PG_RAW_CHARGING_STATIONS
    SHOW_INITIAL_ROWS = TRUE
    COMMENT = 'Captures CDC changes (INSERT/UPDATE/DELETE) on raw charging stations table';
