-- =====================================================================
-- GuardianAI | File 09: EXECUTIVE SUMMARY AGENT (Cortex/CoCo)
-- Generates ONE leadership-ready paragraph summarizing overall data health.
-- Powers the headline text on Page 1 (Data Trust Overview).
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

CREATE OR REPLACE TABLE DQ_EXEC_SUMMARY (
    SUMMARY_TEXT VARCHAR,
    GENERATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Build a compact facts string, then ask Cortex to narrate it.
INSERT INTO DQ_EXEC_SUMMARY (SUMMARY_TEXT)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    CONCAT(
        'You are a Chief Data Officer writing a 3-sentence executive briefing ',
        'on the current state of enterprise data quality. Be direct and calm. ',
        'State the overall trust score, the biggest risks, and the recommended ',
        'priority. Do not use bullet points. Facts: ',
        'Overall trust score: ',
        (SELECT HEALTH_SCORE FROM DQ_HEALTH_SCORE WHERE TABLE_NAME='OVERALL'), '/100. ',
        'Open issues: ', (SELECT COUNT(*) FROM DQ_ISSUES WHERE STATUS='OPEN'), '. ',
        'Critical issues: ',
        (SELECT COUNT(*) FROM DQ_ISSUES WHERE STATUS='OPEN' AND SEVERITY='CRITICAL'), '. ',
        'Worst tables: ',
        (SELECT LISTAGG(TABLE_NAME || ' (' || HEALTH_SCORE || ')', ', ')
         FROM DQ_HEALTH_SCORE WHERE TABLE_NAME <> 'OVERALL'), '.'
    )
);

SELECT SUMMARY_TEXT, GENERATED_AT FROM DQ_EXEC_SUMMARY
ORDER BY GENERATED_AT DESC LIMIT 1;
