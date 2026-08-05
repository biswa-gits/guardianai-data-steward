-- =====================================================================
-- GuardianAI: Autonomous Data Steward for Snowflake
-- File 01: Create database, schema, and warehouse
-- CoCoQuest 2026 | Theme: Agentic Data Quality Guardian
-- Author: Biswajit Jena
-- =====================================================================

-- Create a dedicated database and schema so nothing collides with other work
CREATE DATABASE IF NOT EXISTS GUARDIANAI_DB;
CREATE SCHEMA  IF NOT EXISTS GUARDIANAI_DB.CORE;

-- Small warehouse is plenty for a demo dataset
CREATE WAREHOUSE IF NOT EXISTS GUARDIANAI_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- Quick confirmation
SELECT 'GuardianAI schema ready' AS status,
       CURRENT_DATABASE()        AS db,
       CURRENT_SCHEMA()          AS schema_name,
       CURRENT_WAREHOUSE()       AS warehouse;
