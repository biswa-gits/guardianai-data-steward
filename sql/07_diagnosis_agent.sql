-- =====================================================================
-- GuardianAI | File 07: DIAGNOSIS AGENT (Cortex/CoCo)
-- Reads open issues from DQ_ISSUES and generates a concise ROOT CAUSE.
-- Principle: SQL already detected the issue; Cortex only *reasons* about WHY.
--
-- Uses SNOWFLAKE.CORTEX.COMPLETE. Swap the model name if your account
-- has a different entitlement (e.g. 'llama3.1-8b', 'mistral-large2',
-- 'snowflake-arctic'). For CoCo build accounts, the same COMPLETE call works.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- Refresh analysis for a clean run (seed rows from current open issues)
TRUNCATE TABLE DQ_ISSUE_ANALYSIS;

INSERT INTO DQ_ISSUE_ANALYSIS
    (ISSUE_ID, TABLE_NAME, ISSUE_TYPE, SEVERITY, AFFECTED_ROWS)
SELECT ISSUE_ID, TABLE_NAME, ISSUE_TYPE, SEVERITY, AFFECTED_ROWS
FROM DQ_ISSUES
WHERE STATUS = 'OPEN';

-- ---------------------------------------------------------------------
-- DIAGNOSIS AGENT: fill ROOT_CAUSE
-- The prompt is deliberately tight: 1-2 sentences, data-engineer voice,
-- no fluff, references the table/column and likely upstream cause.
-- ---------------------------------------------------------------------
UPDATE DQ_ISSUE_ANALYSIS a
SET ROOT_CAUSE = SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    CONCAT(
        'You are a senior data quality engineer. In 1 to 2 short sentences, ',
        'explain the most likely ROOT CAUSE of this data quality issue. ',
        'Be specific and technical. Do not restate the issue. Do not give a fix. ',
        'Table: ', a.TABLE_NAME,
        ' | Issue type: ', a.ISSUE_TYPE,
        ' | Severity: ', a.SEVERITY,
        ' | Rows affected: ', a.AFFECTED_ROWS, '.'
    )
)
WHERE a.ROOT_CAUSE IS NULL;

-- Inspect the Diagnosis Agent output
SELECT TABLE_NAME, ISSUE_TYPE, SEVERITY, AFFECTED_ROWS, ROOT_CAUSE
FROM DQ_ISSUE_ANALYSIS
ORDER BY CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                       WHEN 'MEDIUM' THEN 3 ELSE 4 END, TABLE_NAME;
