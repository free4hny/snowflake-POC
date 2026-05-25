select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select STATION_ID
from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
where STATION_ID is null



      
    ) dbt_internal_test