-- ============================================================
-- audit_pipeline_log.sql
-- Purpose: Track every pipeline execution across all layers
-- Run as: EV_DEMO_ADMIN
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.AUDIT;

CREATE TABLE IF NOT EXISTS AUDIT_PIPELINE_LOG (
    LOG_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    PIPELINE_NAME       VARCHAR(200)   NOT NULL,
    LAYER               VARCHAR(20)    NOT NULL,
    SOURCE_TABLE        VARCHAR(500),
    TARGET_TABLE        VARCHAR(500),
    OPERATION           VARCHAR(50)    NOT NULL,
    ROWS_AFFECTED       NUMBER,
    STATUS              VARCHAR(20)    NOT NULL,
    ERROR_MESSAGE       VARCHAR(2000),
    STARTED_AT          TIMESTAMP_NTZ  NOT NULL,
    COMPLETED_AT        TIMESTAMP_NTZ,
    DURATION_SECONDS    NUMBER,
    EXECUTED_BY         VARCHAR(200)   DEFAULT CURRENT_ROLE()
)
COMMENT = 'Tracks every pipeline execution across all layers. Who ran what, when, how many rows.';
