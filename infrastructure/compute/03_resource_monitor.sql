-- ============================================================
-- 03_resource_monitor.sql
-- Purpose: Cap monthly credit usage to prevent runaway costs
-- Run as: ACCOUNTADMIN
-- ============================================================
-- COST NOTES:
--   10 credits/month ≈ $30 on Standard edition
--   Notifies at 75% (7.5 credits used)
--   Suspends warehouse at 90% (current queries finish)
--   Force-kills at 100% (immediate stop)
-- ============================================================

USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS EV_DEMO_MONITOR
    WITH CREDIT_QUOTA = 10
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO SUSPEND
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE EV_DEMO_WH SET RESOURCE_MONITOR = EV_DEMO_MONITOR;
