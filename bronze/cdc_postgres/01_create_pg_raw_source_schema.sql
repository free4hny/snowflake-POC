-- ============================================================
-- 01_create_pg_raw_source_schema.sql
-- Purpose: Create schema for raw CDC events landing from PostgreSQL
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- This schema receives raw change events (INSERT/UPDATE/DELETE)
-- from PostgreSQL. In production, Openflow writes here.
-- In demo, we simulate with manual DML.
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.PG_RAW_SOURCE
    COMMENT = 'Raw CDC events landing zone from PostgreSQL. Append-only change log.';
