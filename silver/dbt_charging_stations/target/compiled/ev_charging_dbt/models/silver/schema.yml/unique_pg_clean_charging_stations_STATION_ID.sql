
    
    

select
    STATION_ID as unique_field,
    count(*) as n_records

from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
where STATION_ID is not null
group by STATION_ID
having count(*) > 1


