-- ============================================================
-- 04_seed_initial_data.sql
-- Purpose: Load initial snapshot of charging stations (simulates first sync)
-- Run as: EV_DEMO_ADMIN
-- ============================================================
-- These 15 stations are in cities matching the EV population data,
-- enabling enrichment joins in the Gold layer.
-- In production: Openflow handles the initial snapshot automatically.
-- ============================================================

USE ROLE EV_DEMO_ADMIN;
USE WAREHOUSE EV_DEMO_WH;
USE SCHEMA EV_POPULATION_DB.PG_RAW_SOURCE;

INSERT INTO PG_RAW_CHARGING_STATIONS
    (STATION_ID, STATION_NAME, CITY, COUNTY, STATE, ZIP_CODE, CONNECTOR_TYPE, POWER_LEVEL_KW, NETWORK, NUM_PORTS, LATITUDE, LONGITUDE)
VALUES
    (1, 'Tesla Supercharger - Oceanside', 'Oceanside', 'San Diego', 'CA', '92051', 'CCS', 250, 'Tesla', 12, 33.1959, -117.3795),
    (2, 'ChargePoint Station - Derby', 'Derby', 'Sedgwick', 'KS', '67037', 'J1772', 7, 'ChargePoint', 4, 37.5456, -97.2689),
    (3, 'EVgo Fast Charge - Marysville', 'Marysville', 'Snohomish', 'WA', '98270', 'CCS', 150, 'EVgo', 6, 48.0518, -122.1771),
    (4, 'Electrify America - Bremerton', 'Bremerton', 'Kitsap', 'WA', '98312', 'CCS', 350, 'Electrify America', 8, 47.5673, -122.6326),
    (5, 'ChargePoint Level 2 - Edmonds', 'Edmonds', 'Snohomish', 'WA', '98020', 'J1772', 7, 'ChargePoint', 2, 47.8107, -122.3774),
    (6, 'Tesla Supercharger - Bellevue', 'Bellevue', 'King', 'WA', '98004', 'CCS', 250, 'Tesla', 16, 47.6101, -122.2015),
    (7, 'Blink Charging - Seattle', 'Seattle', 'King', 'WA', '98101', 'J1772', 7, 'Blink', 3, 47.6062, -122.3321),
    (8, 'EVgo DC Fast - Tacoma', 'Tacoma', 'Pierce', 'WA', '98402', 'CHAdeMO', 100, 'EVgo', 4, 47.2529, -122.4443),
    (9, 'Electrify America - Olympia', 'Olympia', 'Thurston', 'WA', '98501', 'CCS', 350, 'Electrify America', 6, 47.0379, -122.9007),
    (10, 'ChargePoint - Spokane', 'Spokane', 'Spokane', 'WA', '99201', 'J1772', 7, 'ChargePoint', 4, 47.6588, -117.4260),
    (11, 'Tesla Supercharger - Vancouver', 'Vancouver', 'Clark', 'WA', '98660', 'CCS', 250, 'Tesla', 10, 45.6387, -122.6615),
    (12, 'Blink Charging - Renton', 'Renton', 'King', 'WA', '98057', 'J1772', 7, 'Blink', 2, 47.4829, -122.2171),
    (13, 'EVgo Fast Charge - Lynnwood', 'Lynnwood', 'Snohomish', 'WA', '98036', 'CCS', 150, 'EVgo', 4, 47.8209, -122.3151),
    (14, 'ChargePoint DC - Kirkland', 'Kirkland', 'King', 'WA', '98033', 'CCS', 62, 'ChargePoint', 2, 47.6815, -122.2087),
    (15, 'Electrify America - Kent', 'Kent', 'King', 'WA', '98032', 'CCS', 350, 'Electrify America', 8, 47.3809, -122.2348);
