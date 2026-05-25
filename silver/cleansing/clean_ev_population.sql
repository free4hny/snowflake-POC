-- ============================================================
-- clean_ev_population.sql
-- Purpose: Dynamic Table — transforms Bronze VARIANT to typed Silver columns
-- Run as: EV_DEMO_ADMIN
-- Prerequisite: GRANT CREATE DYNAMIC TABLE ON SCHEMA SILVER TO ROLE EV_DEMO_ADMIN
-- ============================================================
-- TRANSFORMS:
--   1. VARIANT positional access → named typed columns
--   2. TRIM + UPPER/INITCAP for consistency
--   3. NULLIF(0) for range/MSRP (0 = no data, not zero miles)
--   4. Dedup: ROW_NUMBER by VIN+Year, keep latest LOADED_AT
--   5. Filter: exclude NULL VINs (already in DLQ)
--
-- AUTO-REFRESH:
--   TARGET_LAG = 1 hour → refreshes within 1 hour of Bronze changes
--   Cost: ~0.02 credits per refresh (XS warehouse)
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

CREATE OR REPLACE DYNAMIC TABLE EV_POPULATION_DB.SILVER.CLEAN_EV_POPULATION
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_DEMO_WH
AS
SELECT
    RAW_DATA[8]::VARCHAR(10)    AS VIN,
    TRIM(UPPER(RAW_DATA[9]::STRING))   AS COUNTY,
    TRIM(INITCAP(RAW_DATA[10]::STRING)) AS CITY,
    UPPER(RAW_DATA[11]::STRING) AS STATE,
    RAW_DATA[12]::VARCHAR(10)   AS ZIP_CODE,
    RAW_DATA[13]::NUMBER        AS MODEL_YEAR,
    TRIM(UPPER(RAW_DATA[14]::STRING))  AS MAKE,
    TRIM(UPPER(RAW_DATA[15]::STRING))  AS MODEL,
    RAW_DATA[16]::VARCHAR(100)  AS EV_TYPE,
    RAW_DATA[17]::VARCHAR(200)  AS CAFV_ELIGIBILITY,
    NULLIF(RAW_DATA[18]::NUMBER, 0) AS ELECTRIC_RANGE,
    NULLIF(RAW_DATA[19]::NUMBER, 0) AS BASE_MSRP,
    RAW_DATA[20]::NUMBER        AS LEGISLATIVE_DISTRICT,
    RAW_DATA[21]::VARCHAR(20)   AS DOL_VEHICLE_ID,
    RAW_DATA[22]::VARCHAR(200)  AS VEHICLE_LOCATION,
    RAW_DATA[23]::VARCHAR(200)  AS ELECTRIC_UTILITY,
    RAW_DATA[24]::VARCHAR(20)   AS CENSUS_TRACT,
    SOURCE_FILE_NAME,
    LOADED_AT
FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION
WHERE RAW_DATA[8] IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY RAW_DATA[8]::STRING, RAW_DATA[13]::STRING ORDER BY LOADED_AT DESC) = 1;
