
  
    

        create or replace transient table EV_POPULATION_DB.SILVER.pg_clean_charging_stations
         as
        (

SELECT
    STATION_ID,
    TRIM(STATION_NAME)              AS STATION_NAME,
    TRIM(INITCAP(CITY))             AS CITY,
    TRIM(UPPER(COUNTY))             AS COUNTY,
    UPPER(STATE)                    AS STATE,
    TRIM(ZIP_CODE)                  AS ZIP_CODE,
    UPPER(CONNECTOR_TYPE)           AS CONNECTOR_TYPE,
    POWER_LEVEL_KW,
    TRIM(NETWORK)                   AS NETWORK,
    NUM_PORTS,
    UPPER(STATUS)                   AS STATION_STATUS,
    LATITUDE,
    LONGITUDE,
    LAST_UPDATED,
    MERGED_AT
FROM EV_POPULATION_DB.PG_BRONZE.PG_CHARGING_STATIONS
WHERE IS_DELETED = FALSE
  AND STATION_ID IS NOT NULL
  AND POWER_LEVEL_KW BETWEEN 1 AND 500
        );
      
  