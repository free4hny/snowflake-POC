select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CITY
from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
where CITY is null



      
    ) dbt_internal_test