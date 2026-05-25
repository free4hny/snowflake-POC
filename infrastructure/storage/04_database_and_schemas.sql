-- ============================================================
-- 04_database_and_schemas.sql
-- Purpose: Create the database and medallion layer schemas
-- Run as: SYSADMIN
-- ============================================================
-- SCHEMA LAYOUT:
--   BRONZE          = Raw file-based data (JSON) as-is from source
--   PG_RAW_SOURCE   = Raw CDC events landing from PostgreSQL
--   PG_BRONZE       = Reconciled current-state from PostgreSQL CDC
--   SILVER          = Cleaned, typed, deduplicated, validated
--   GOLD            = Business aggregations, KPIs, dimensional models
--   AUDIT           = Pipeline logs, row counts, DQ results
--   UTILITIES       = Shared stages, file formats, Git repo, UDFs
-- ============================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS EV_POPULATION_DB
    COMMENT = 'EV Population Data Engineering Demo - Medallion Architecture';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.BRONZE
    COMMENT = 'Raw ingested data. No transformations. Append-only.';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.SILVER
    COMMENT = 'Cleaned, typed, deduplicated. Data quality checks applied.';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.GOLD
    COMMENT = 'Business-ready: aggregations, KPIs, dimensional models.';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.AUDIT
    COMMENT = 'Pipeline audit logs, row counts, data quality results at every layer.';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.UTILITIES
    COMMENT = 'Shared file formats, internal stages, Git repo, helper UDFs.';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.PG_RAW_SOURCE
    COMMENT = 'Raw CDC events landing zone from PostgreSQL. Append-only change log.';

CREATE SCHEMA IF NOT EXISTS EV_POPULATION_DB.PG_BRONZE
    COMMENT = 'Reconciled current-state data from PostgreSQL CDC. Merged via Stream+Task.';

-- Transfer ownership to EV_DEMO_ADMIN
USE ROLE SECURITYADMIN;
GRANT OWNERSHIP ON DATABASE EV_POPULATION_DB TO ROLE EV_DEMO_ADMIN COPY CURRENT GRANTS;
