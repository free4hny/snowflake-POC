-- ============================================================
-- 03_pg_raw_charging_stations.sql
-- Purpose: Create raw landing table for charging stations CDC events
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- CHANGE_TRACKING = TRUE enables Snowflake Streams on this table.
-- Structure mirrors PostgreSQL source table exactly.
-- In production: Openflow writes here automatically.
-- In demo: we simulate with INSERT/UPDATE/DELETE statements.
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.PG_RAW_SOURCE;

CREATE TABLE IF NOT EXISTS PG_RAW_CHARGING_STATIONS (
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
    LAST_UPDATED       TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()
)
CHANGE_TRACKING = TRUE
COMMENT = 'Raw charging stations from PostgreSQL. Change tracking enabled for CDC stream.';
