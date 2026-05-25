-- ============================================================
-- dlq_tables.sql
-- Purpose: Dead Letter Queue tables — one per layer
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- FLOW:
--   DQ check fails for a row → row moved to DLQ → pipeline continues with clean rows
--   Later: manually fix → redrive back into pipeline → update STATUS = 'REDRIVEN'
--
-- STATUS values: QUARANTINED | REDRIVEN | DISCARDED
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.AUDIT;

CREATE TABLE IF NOT EXISTS DLQ_BRONZE (
    DLQ_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_TABLE        VARCHAR(500)   NOT NULL,
    FAILED_CHECK        VARCHAR(200)   NOT NULL,
    RAW_RECORD          VARIANT        NOT NULL,
    FAILURE_REASON      VARCHAR(1000),
    QUARANTINED_AT      TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    REDRIVEN_AT         TIMESTAMP_NTZ,
    REDRIVEN_BY         VARCHAR(200),
    STATUS              VARCHAR(20)    DEFAULT 'QUARANTINED'
)
COMMENT = 'Dead letter queue for Bronze layer. Failed rows parked here for manual fix and redrive.';

CREATE TABLE IF NOT EXISTS DLQ_SILVER (
    DLQ_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_TABLE        VARCHAR(500)   NOT NULL,
    FAILED_CHECK        VARCHAR(200)   NOT NULL,
    RAW_RECORD          VARIANT        NOT NULL,
    FAILURE_REASON      VARCHAR(1000),
    QUARANTINED_AT      TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    REDRIVEN_AT         TIMESTAMP_NTZ,
    REDRIVEN_BY         VARCHAR(200),
    STATUS              VARCHAR(20)    DEFAULT 'QUARANTINED'
)
COMMENT = 'Dead letter queue for Silver layer. Failed rows parked here for manual fix and redrive.';

CREATE TABLE IF NOT EXISTS DLQ_GOLD (
    DLQ_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_TABLE        VARCHAR(500)   NOT NULL,
    FAILED_CHECK        VARCHAR(200)   NOT NULL,
    RAW_RECORD          VARIANT        NOT NULL,
    FAILURE_REASON      VARCHAR(1000),
    QUARANTINED_AT      TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    REDRIVEN_AT         TIMESTAMP_NTZ,
    REDRIVEN_BY         VARCHAR(200),
    STATUS              VARCHAR(20)    DEFAULT 'QUARANTINED'
)
COMMENT = 'Dead letter queue for Gold layer. Failed rows parked here for manual fix and redrive.';
