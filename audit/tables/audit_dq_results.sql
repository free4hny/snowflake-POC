-- ============================================================
-- audit_dq_results.sql
-- Purpose: Log all data quality check results
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- CHECK_TYPES: NULL_CHECK, DUPLICATE_CHECK, ROW_COUNT_MATCH,
--              RANGE_CHECK, FRESHNESS_CHECK, SCHEMA_CHECK
-- STATUS: PASS, WARN, FAIL
-- DETAILS (VARIANT): stores context as JSON, e.g.
--   {"source_count": 22183, "target_count": 22183}
--   {"column": "VIN", "null_count": 5, "total_rows": 22183}
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.AUDIT;

CREATE TABLE IF NOT EXISTS AUDIT_DQ_RESULTS (
    DQ_ID               NUMBER AUTOINCREMENT PRIMARY KEY,
    CHECK_NAME          VARCHAR(200)   NOT NULL,
    TABLE_NAME          VARCHAR(500)   NOT NULL,
    LAYER               VARCHAR(20)    NOT NULL,
    CHECK_TYPE          VARCHAR(50)    NOT NULL,
    ROWS_CHECKED        NUMBER,
    ROWS_FAILED         NUMBER,
    PASS_RATE           NUMBER(5,2),
    STATUS              VARCHAR(20)    NOT NULL,
    THRESHOLD           NUMBER(5,2),
    CHECKED_AT          TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    DETAILS             VARIANT
)
COMMENT = 'All data quality check results: nulls, duplicates, row counts, ranges, freshness.';
