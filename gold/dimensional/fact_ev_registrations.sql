-- ============================================================
-- fact_ev_registrations.sql
-- Purpose: Fact table — one row per registered EV vehicle
-- Method: Dynamic Table on SILVER.CLEAN_EV_POPULATION
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

CREATE OR REPLACE DYNAMIC TABLE EV_POPULATION_DB.GOLD.FACT_EV_REGISTRATIONS
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_DEMO_WH
AS
SELECT
    VIN,
    DOL_VEHICLE_ID,
    MAKE,
    MODEL,
    MODEL_YEAR,
    EV_TYPE,
    CAFV_ELIGIBILITY,
    ELECTRIC_RANGE,
    BASE_MSRP,
    CITY,
    COUNTY,
    STATE,
    ZIP_CODE,
    LEGISLATIVE_DISTRICT,
    ELECTRIC_UTILITY,
    CENSUS_TRACT,
    VEHICLE_LOCATION,
    CASE WHEN EV_TYPE = 'Battery Electric Vehicle (BEV)' THEN 'BEV' ELSE 'PHEV' END AS EV_TYPE_SHORT,
    CASE WHEN CAFV_ELIGIBILITY LIKE '%Eligible%' THEN TRUE ELSE FALSE END AS IS_CAFV_ELIGIBLE,
    LOADED_AT AS REGISTERED_AT
FROM EV_POPULATION_DB.SILVER.CLEAN_EV_POPULATION;
