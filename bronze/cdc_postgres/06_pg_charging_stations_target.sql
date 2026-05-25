-- ============================================================
-- 06_pg_charging_stations_target.sql
-- Purpose: Create merge target table in PG_BRONZE (current state)
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- This table represents the latest reconciled state of PostgreSQL data.
-- MERGE task writes here from the stream.
-- IS_DELETED = soft delete flag (preserves audit trail).
-- MERGED_AT = timestamp of last merge operation.
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.PG_BRONZE;

CREATE TABLE IF NOT EXISTS PG_CHARGING_STATIONS (
    STATION_ID         NUMBER         PRIMARY KEY,
    STATION_NAME       VARCHAR(200)   NOT NULL,
    CITY               VARCHAR(100)   NOT NULL,
    COUNTY             VARCHAR(100)   NOT NULL,
    STATE              VARCHAR(2)     NOT NULL,
    ZIP_CODE           VARCHAR(10)    NOT NULL,
    CONNECTOR_TYPE     VARCHAR(50)    NOT NULL,
    POWER_LEVEL_KW     NUMBER         NOT NULL,
    NETWORK            VARCHAR(100),
    NUM_PORTS          NUMBER         DEFAULT 1,
    STATUS             VARCHAR(20)    DEFAULT 'Active',
    LATITUDE           NUMBER(10,6),
    LONGITUDE          NUMBER(10,6),
    LAST_UPDATED       TIMESTAMP_NTZ,
    MERGED_AT          TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    IS_DELETED         BOOLEAN        DEFAULT FALSE
)
COMMENT = 'Current-state charging stations. Merged from PG_RAW_SOURCE via CDC stream.';
