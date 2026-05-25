select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    STATION_ID as unique_field,
    count(*) as n_records

from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
where STATION_ID is not null
group by STATION_ID
having count(*) > 1



      
    ) dbt_internal_test