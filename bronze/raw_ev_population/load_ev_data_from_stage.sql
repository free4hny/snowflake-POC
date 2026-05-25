-- ============================================================
-- load_ev_data_from_stage.sql
-- Purpose: Load staged JSON into Bronze raw table via INSERT+FLATTEN
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- NOTES:
--   This JSON is Socrata Open Data format (nested data[] array).
--   We use LATERAL FLATTEN to explode each row into its own record.
--   Each array element becomes one VARIANT row in Bronze.
--   SOURCE_FILE_NAME + SOURCE_FILE_ROW enable lineage tracking.
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;

INSERT INTO EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION (
    RAW_DATA,
    SOURCE_FILE_NAME,
    SOURCE_FILE_ROW,
    LOADED_AT
)
SELECT
    f.value AS RAW_DATA,
    'ev_population/ElectricVehiclePopulationData.json' AS SOURCE_FILE_NAME,
    f.index AS SOURCE_FILE_ROW,
    CURRENT_TIMESTAMP()
FROM @EV_POPULATION_DB.UTILITIES.EV_RAW_STAGE/ev_population/ElectricVehiclePopulationData.json
    (FILE_FORMAT => 'EV_POPULATION_DB.UTILITIES.JSON_RAW_FORMAT') t,
    LATERAL FLATTEN(input => t.$1:data) f;

-- Verify load
SELECT COUNT(*) AS rows_loaded FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION;
SELECT RAW_DATA[14]::STRING AS make, RAW_DATA[15]::STRING AS model, RAW_DATA[13]::STRING AS year
FROM EV_POPULATION_DB.BRONZE.RAW_EV_POPULATION LIMIT 5;
