-- ============================================================
-- 07_git_integration.sql
-- Purpose: Connect Snowflake to GitHub repo for version control
-- Run as: ACCOUNTADMIN (integration) + EV_DEMO_ADMIN (repo)
-- ============================================================
-- NOTES:
--   Public repo = no secret/PAT needed
--   API Integration = allows Snowflake to talk to GitHub HTTPS
--   Git Repository = clones repo metadata into Snowflake
--   Use ALTER GIT REPOSITORY ... FETCH to pull latest changes
-- ============================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE API INTEGRATION ev_git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/free4hny')
    ENABLED = TRUE
    COMMENT = 'API integration for EV demo Git repo (public, no auth needed)';

GRANT USAGE ON INTEGRATION ev_git_api_integration TO ROLE EV_DEMO_ADMIN;

-- Create Git Repository
USE ROLE EV_DEMO_ADMIN;
USE SCHEMA EV_POPULATION_DB.UTILITIES;

CREATE OR REPLACE GIT REPOSITORY EV_GIT_REPO
    API_INTEGRATION = ev_git_api_integration
    ORIGIN = 'https://github.com/free4hny/snowflake-POC.git'
    COMMENT = 'Git-backed project for EV Population demo';

-- Fetch latest and verify
ALTER GIT REPOSITORY EV_GIT_REPO FETCH;
SHOW GIT BRANCHES IN GIT REPOSITORY EV_GIT_REPO;
