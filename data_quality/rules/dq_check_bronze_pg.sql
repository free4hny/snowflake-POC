-- ============================================================
-- dq_check_bronze_pg.sql
-- Purpose: Data quality checks for Bronze CDC PostgreSQL data
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- CHECKS:
--   1. NULL_STATION_ID     — Station ID must not be null (0% tolerance)
--   2. DUPLICATE_STATION_ID — No duplicate active stations
--   3. RANGE_POWER_LEVEL_KW — Must be between 1-500 kW
--   4. ROW_COUNT_MATCH     — RAW source count must match Bronze active count
--
-- ON FAIL: Rows moved to AUDIT.DLQ_BRONZE for manual fix
-- RESULTS: Logged to AUDIT.AUDIT_DQ_RESULTS
--
-- USAGE:
--   CALL EV_POPULATION_DB.AUDIT.SP_DQ_CHECK_BRONZE_PG();
--   SELECT * FROM EV_POPULATION_DB.AUDIT.AUDIT_DQ_RESULTS WHERE TABLE_NAME LIKE '%PG%';
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.AUDIT;

CREATE OR REPLACE PROCEDURE SP_DQ_CHECK_BRONZE_PG()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    LET total_rows NUMBER := 0;
    LET failed_rows NUMBER := 0;
    LET pass_rate FLOAT := 0.0;
    LET check_status VARCHAR := '';
    LET details VARIANT;

    SELECT COUNT(*) INTO :total_rows
    FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS WHERE IS_DELETED = FALSE;

    -- CHECK 1: NULL Station ID — 0% tolerance
    SELECT COUNT(*) INTO :failed_rows
    FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
    WHERE STATION_ID IS NULL AND IS_DELETED = FALSE;

    check_status := CASE WHEN :failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END;
    details := PARSE_JSON('{"column":"STATION_ID","null_count":' || :failed_rows || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'NULL_STATION_ID', 'PG_BRONZE.PG_CHARGING_STATIONS', 'BRONZE', 'NULL_CHECK', :total_rows, :failed_rows, 100, :check_status, 100.00, :details;

    -- CHECK 2: Duplicate Station ID — 0% tolerance
    SELECT COUNT(*) INTO :failed_rows
    FROM (
        SELECT STATION_ID, COUNT(*) AS cnt
        FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
        WHERE IS_DELETED = FALSE GROUP BY STATION_ID HAVING cnt > 1
    );

    check_status := CASE WHEN :failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END;
    details := PARSE_JSON('{"duplicate_groups":' || :failed_rows || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'DUPLICATE_STATION_ID', 'PG_BRONZE.PG_CHARGING_STATIONS', 'BRONZE', 'DUPLICATE_CHECK', :total_rows, :failed_rows, NULL, :check_status, 0, :details;

    -- CHECK 3: Range power_level_kw (1-500 kW)
    SELECT COUNT(*) INTO :failed_rows
    FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
    WHERE IS_DELETED = FALSE AND (POWER_LEVEL_KW < 1 OR POWER_LEVEL_KW > 500);

    pass_rate := CASE WHEN :total_rows = 0 THEN 100.0 ELSE ROUND((1.0 - :failed_rows::FLOAT / :total_rows::FLOAT) * 100, 2) END;
    check_status := CASE WHEN :failed_rows = 0 THEN 'PASS' ELSE 'WARN' END;
    details := PARSE_JSON('{"column":"POWER_LEVEL_KW","valid_range":"1-500","out_of_range":' || :failed_rows || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'RANGE_POWER_LEVEL_KW', 'PG_BRONZE.PG_CHARGING_STATIONS', 'BRONZE', 'RANGE_CHECK', :total_rows, :failed_rows, :pass_rate, :check_status, 100.00, :details;

    IF (:failed_rows > 0) THEN
        INSERT INTO DLQ_BRONZE (SOURCE_TABLE, FAILED_CHECK, RAW_RECORD, FAILURE_REASON)
        SELECT 'PG_BRONZE.PG_CHARGING_STATIONS', 'RANGE_POWER_LEVEL_KW',
               OBJECT_CONSTRUCT('STATION_ID', STATION_ID, 'STATION_NAME', STATION_NAME, 'POWER_LEVEL_KW', POWER_LEVEL_KW),
               'POWER_LEVEL_KW out of range (1-500): ' || POWER_LEVEL_KW::VARCHAR
        FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
        WHERE IS_DELETED = FALSE AND (POWER_LEVEL_KW < 1 OR POWER_LEVEL_KW > 500);
    END IF;

    -- CHECK 4: Row count RAW vs BRONZE
    LET raw_count NUMBER := 0;
    LET deleted_count NUMBER := 0;
    LET diff NUMBER := 0;

    SELECT COUNT(*) INTO :raw_count FROM EV_POPULATION_DB.PG_RAW_SOURCE.PG_RAW_CHARGING_STATIONS;
    SELECT COUNT(*) INTO :deleted_count FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS WHERE IS_DELETED = TRUE;

    diff := :raw_count - :total_rows;
    check_status := CASE WHEN :diff = 0 THEN 'PASS' ELSE 'WARN' END;
    details := PARSE_JSON('{"raw_count":' || :raw_count || ',"bronze_active":' || :total_rows || ',"soft_deleted":' || :deleted_count || ',"difference":' || :diff || '}');

    INSERT INTO AUDIT_DQ_RESULTS (CHECK_NAME, TABLE_NAME, LAYER, CHECK_TYPE, ROWS_CHECKED, ROWS_FAILED, PASS_RATE, STATUS, THRESHOLD, DETAILS)
    SELECT 'ROW_COUNT_RAW_VS_BRONZE_PG', 'PG_BRONZE.PG_CHARGING_STATIONS', 'BRONZE', 'ROW_COUNT_MATCH', :total_rows, ABS(:diff), NULL, :check_status, 0, :details;

    RETURN 'DQ checks completed for PG_BRONZE.PG_CHARGING_STATIONS. Active rows: ' || :total_rows;
END;
