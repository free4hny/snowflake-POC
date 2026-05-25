-- ============================================================
-- dq_check_bronze_ev.sql
-- Purpose: Data quality checks for Bronze EV Population data
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- CHECKS:
--   1. NULL_VIN_CHECK      — VIN must not be null (0% tolerance)
--   2. NULL_MAKE_CHECK     — Make must not be null (95% threshold)
--   3. DUPLICATE_VIN_YEAR  — Same VIN+Year should not repeat
--   4. ROW_COUNT_MATCH     — Staging count must match Bronze count
--
-- ON FAIL: Rows moved to AUDIT.DLQ_BRONZE for manual fix
-- RESULTS: Logged to AUDIT.AUDIT_DQ_RESULTS
--
-- USAGE:
--   CALL EV_POPULATION_DB.AUDIT.SP_DQ_CHECK_BRONZE_EV();
--   SELECT * FROM EV_POPULATION_DB.AUDIT.AUDIT_DQ_RESULTS WHERE LAYER = 'BRONZE';
--   SELECT * FROM EV_POPULATION_DB.AUDIT.DLQ_BRONZE;
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.AUDIT;

CREATE OR REPLACE PROCEDURE SP_DQ_CHECK_BRONZE_EV()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    LET total_rows NUMBER := 0;
    LET failed_rows NUMBER := 0;
    LET pass_rate FLOAT := 0.0;
    LET check_status VARCHAR := '';
    LET details VARIANT;

    SELECT COUNT(*) INTO :total_rows FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION;

    -- CHECK 1: NULL VIN (position 8) — 0% tolerance
    SELECT COUNT(*) INTO :failed_rows
    FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION
    WHERE RAW_DATA[8] IS NULL OR RAW_DATA[8]::STRING = '';

    pass_rate := CASE WHEN :total_rows = 0 THEN 100.0 ELSE ROUND((1.0 - :failed_rows::FLOAT / :total_rows::FLOAT) * 100, 2) END;
    check_status := CASE WHEN :failed_rows = 0 THEN 'PASS' ELSE 'WARN' END;
    details := PARSE_JSON('{"column":"VIN","null_count":' || :failed_rows || ',"total_rows":' || :total_rows || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'NULL_VIN_CHECK', 'BRONZE.RAW_EV_POPULATION', 'BRONZE', 'NULL_CHECK', :total_rows, :failed_rows, :pass_rate, :check_status, 100.00, :details;

    IF (:failed_rows > 0) THEN
        INSERT INTO DLQ_BRONZE (SOURCE_TABLE, FAILED_CHECK, RAW_RECORD, FAILURE_REASON)
        SELECT 'BRONZE.RAW_EV_POPULATION', 'NULL_VIN_CHECK', RAW_DATA, 'VIN is NULL or empty'
        FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION
        WHERE RAW_DATA[8] IS NULL OR RAW_DATA[8]::STRING = '';
    END IF;

    -- CHECK 2: NULL Make (position 14) — 95% threshold
    SELECT COUNT(*) INTO :failed_rows
    FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION
    WHERE RAW_DATA[14] IS NULL OR RAW_DATA[14]::STRING = '';

    pass_rate := CASE WHEN :total_rows = 0 THEN 100.0 ELSE ROUND((1.0 - :failed_rows::FLOAT / :total_rows::FLOAT) * 100, 2) END;
    check_status := CASE WHEN :pass_rate >= 95 THEN 'PASS' WHEN :pass_rate >= 90 THEN 'WARN' ELSE 'FAIL' END;
    details := PARSE_JSON('{"column":"MAKE","null_count":' || :failed_rows || ',"total_rows":' || :total_rows || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'NULL_MAKE_CHECK', 'BRONZE.RAW_EV_POPULATION', 'BRONZE', 'NULL_CHECK', :total_rows, :failed_rows, :pass_rate, :check_status, 95.00, :details;

    IF (:failed_rows > 0) THEN
        INSERT INTO DLQ_BRONZE (SOURCE_TABLE, FAILED_CHECK, RAW_RECORD, FAILURE_REASON)
        SELECT 'BRONZE.RAW_EV_POPULATION', 'NULL_MAKE_CHECK', RAW_DATA, 'Make is NULL or empty'
        FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION
        WHERE RAW_DATA[14] IS NULL OR RAW_DATA[14]::STRING = '';
    END IF;

    -- CHECK 3: Duplicate VIN+Year
    SELECT COUNT(*) INTO :failed_rows
    FROM (
        SELECT RAW_DATA[8]::STRING AS vin, RAW_DATA[13]::STRING AS yr, COUNT(*) AS cnt
        FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION
        WHERE RAW_DATA[8] IS NOT NULL
        GROUP BY vin, yr HAVING cnt > 1
    );

    check_status := CASE WHEN :failed_rows = 0 THEN 'PASS' ELSE 'WARN' END;
    details := PARSE_JSON('{"duplicate_groups":' || :failed_rows || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'DUPLICATE_VIN_YEAR', 'BRONZE.RAW_EV_POPULATION', 'BRONZE', 'DUPLICATE_CHECK', :total_rows, :failed_rows, NULL, :check_status, 0, :details;

    -- CHECK 4: Row count vs staging
    LET staging_count NUMBER := 0;
    LET expected_rows NUMBER := 0;
    LET diff NUMBER := 0;

    SELECT COUNT(*) INTO :staging_count FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION_STAGING;
    IF (:staging_count > 0) THEN
        SELECT SUM(ARRAY_SIZE(RAW_FILE:data)) INTO :expected_rows FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION_STAGING;
    END IF;

    diff := :expected_rows - :total_rows;
    check_status := CASE WHEN :diff = 0 OR :staging_count = 0 THEN 'PASS' ELSE 'WARN' END;
    details := PARSE_JSON('{"staging_expected":' || :expected_rows || ',"bronze_actual":' || :total_rows || ',"difference":' || :diff || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'ROW_COUNT_STAGING_VS_BRONZE', 'BRONZE.RAW_EV_POPULATION', 'BRONZE', 'ROW_COUNT_MATCH', :total_rows, ABS(:diff), NULL, :check_status, 0, :details;

    RETURN 'DQ checks completed for BRONZE.RAW_EV_POPULATION. Total rows: ' || :total_rows;
END;
