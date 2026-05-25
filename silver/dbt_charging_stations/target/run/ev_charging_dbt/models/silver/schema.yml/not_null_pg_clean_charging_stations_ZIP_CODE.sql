select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ZIP_CODE
from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
where ZIP_CODE is null



      
    ) dbt_internal_test