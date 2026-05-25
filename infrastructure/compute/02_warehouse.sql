-- ============================================================
-- 02_warehouse.sql
-- Purpose: Create cost-safe XS warehouse for all demo workloads
-- Run as: SYSADMIN
-- ============================================================
-- COST NOTES:
--   X-SMALL = 1 credit/hour (smallest available)
--   AUTO_SUSPEND = 60s means you pay only for active seconds
--   INITIALLY_SUSPENDED = no cost at creation time
--   STATEMENT_TIMEOUT = kills runaway queries after 5 minutes
-- ============================================================

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS EV_DEMO_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 300
    COMMENT = 'XS warehouse for EV demo. 60s auto-suspend, 5min query timeout.';
