select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select POWER_LEVEL_KW
from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
where POWER_LEVEL_KW is null



      
    ) dbt_internal_test