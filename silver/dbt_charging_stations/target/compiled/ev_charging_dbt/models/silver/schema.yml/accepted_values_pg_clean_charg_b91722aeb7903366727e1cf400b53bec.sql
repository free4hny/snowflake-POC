
    
    

with all_values as (

    select
        STATE as value_field,
        count(*) as n_records

    from EV_POPULATION_DB.SILVER.pg_clean_charging_stations
    group by STATE

)

select *
from all_values
where value_field not in (
    'WA','CA','OR','KS','TX','NY','FL','CO','AZ','NV','IL','MA'
)


