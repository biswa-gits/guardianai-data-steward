-- =====================================================================
-- GuardianAI | File 06: AI analysis storage (Day 2 - Intelligence layer)
-- One row per issue, holding the Cortex/CoCo generated reasoning.
-- The Diagnosis Agent and Business Impact Agent both write here.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

CREATE OR REPLACE TABLE DQ_ISSUE_ANALYSIS (
    ISSUE_ID        VARCHAR,        -- FK back to DQ_ISSUES.ISSUE_ID
    TABLE_NAME      VARCHAR,
    ISSUE_TYPE      VARCHAR,
    SEVERITY        VARCHAR,
    AFFECTED_ROWS   NUMBER,
    ROOT_CAUSE      VARCHAR,        -- from Diagnosis Agent
    BUSINESS_IMPACT VARCHAR,        -- from Business Impact Agent
    IMPACT_LEVEL    VARCHAR,        -- HIGH / MEDIUM / LOW (parsed from impact)
    ANALYZED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SELECT 'DQ_ISSUE_ANALYSIS table ready' AS status;
