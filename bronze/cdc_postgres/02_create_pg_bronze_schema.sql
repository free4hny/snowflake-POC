-- ============================================================
-- 02_create_pg_bronze_schema.sql
-- Purpose: Create schema for reconciled current-state PostgreSQL data
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- This schema holds the merged/reconciled view of PostgreSQL data.
-- Stream + Task MERGE from PG_RAW_SOURCE into here.
-- Represents "what PostgreSQL looks like right now".
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.PG_BRONZE
    COMMENT = 'Reconciled current-state data from PostgreSQL CDC. Merged via Stream+Task.';
