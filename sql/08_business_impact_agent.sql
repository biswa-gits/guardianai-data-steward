-- =====================================================================
-- GuardianAI | File 08: BUSINESS IMPACT AGENT (Cortex/CoCo)
-- Translates each technical issue into executive-language business impact.
-- This drives the 25% "business value narrative" scoring weight.
-- Runs AFTER the Diagnosis Agent (07) so it can use the root cause too.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- BUSINESS IMPACT AGENT: fill BUSINESS_IMPACT (executive voice)
-- Prompt asks for: who is affected, what breaks downstream, why it matters
-- in business terms (revenue, compliance, customer trust, reporting).
-- ---------------------------------------------------------------------
UPDATE DQ_ISSUE_ANALYSIS a
SET BUSINESS_IMPACT = SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    CONCAT(
        'You are a data governance lead briefing executives. In 2 short sentences, ',
        'explain the BUSINESS IMPACT of this data issue in plain, non-technical language. ',
        'Focus on revenue, compliance, customer trust, or reporting accuracy. ',
        'Do not use technical jargon. Do not suggest a fix. ',
        'Table: ', a.TABLE_NAME,
        ' | Issue: ', a.ISSUE_TYPE,
        ' | Severity: ', a.SEVERITY,
        ' | Rows affected: ', a.AFFECTED_ROWS,
        ' | Likely root cause: ', COALESCE(a.ROOT_CAUSE, 'n/a'), '.'
    )
)
WHERE a.BUSINESS_IMPACT IS NULL;

-- ---------------------------------------------------------------------
-- Derive a simple IMPACT_LEVEL from severity (deterministic, not AI -
-- keeps the dashboard sortable and avoids parsing free text).
-- ---------------------------------------------------------------------
UPDATE DQ_ISSUE_ANALYSIS
SET IMPACT_LEVEL = CASE SEVERITY
        WHEN 'CRITICAL' THEN 'HIGH'
        WHEN 'HIGH'     THEN 'HIGH'
        WHEN 'MEDIUM'   THEN 'MEDIUM'
        ELSE 'LOW'
    END
WHERE IMPACT_LEVEL IS NULL;

-- Full intelligence view - Diagnosis + Impact together
SELECT TABLE_NAME, ISSUE_TYPE, SEVERITY, IMPACT_LEVEL,
       AFFECTED_ROWS, ROOT_CAUSE, BUSINESS_IMPACT
FROM DQ_ISSUE_ANALYSIS
ORDER BY CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                       WHEN 'MEDIUM' THEN 3 ELSE 4 END, TABLE_NAME;
