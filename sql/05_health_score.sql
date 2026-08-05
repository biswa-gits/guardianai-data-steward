-- =====================================================================
-- GuardianAI | File 05: Health Score model
-- Formula (strategy brief Section 12): Health Score = 100 - Weighted Penalty
-- Penalty per issue is (PENALTY * scaling), capped so score stays 0-100.
-- Also derives a simple Business Risk band per table + an overall score.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- Refresh the score table each run
TRUNCATE TABLE DQ_HEALTH_SCORE;

-- Per-table health score.
-- We sum the penalty per detected issue type (one row = one issue type).
-- Score is floored at 0 and rounded to a whole number.
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
SELECT
    TABLE_NAME,
    SUM(PENALTY)                                   AS TOTAL_PENALTY,
    GREATEST(0, 100 - SUM(PENALTY))                AS HEALTH_SCORE,
    CASE
        WHEN GREATEST(0, 100 - SUM(PENALTY)) >= 90 THEN 'LOW'
        WHEN GREATEST(0, 100 - SUM(PENALTY)) >= 75 THEN 'MEDIUM'
        WHEN GREATEST(0, 100 - SUM(PENALTY)) >= 50 THEN 'HIGH'
        ELSE 'CRITICAL'
    END                                            AS BUSINESS_RISK
FROM DQ_ISSUES
WHERE STATUS = 'OPEN'
GROUP BY TABLE_NAME;

-- Overall data trust score = average of table scores
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
SELECT
    'OVERALL',
    SUM(TOTAL_PENALTY),
    ROUND(AVG(HEALTH_SCORE)),
    CASE
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 90 THEN 'LOW'
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 75 THEN 'MEDIUM'
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 50 THEN 'HIGH'
        ELSE 'CRITICAL'
    END
FROM DQ_HEALTH_SCORE
WHERE TABLE_NAME <> 'OVERALL';

-- Final scoreboard - this is what Page 1 (Data Trust Overview) will show
SELECT TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK, SCORED_AT
FROM DQ_HEALTH_SCORE
ORDER BY CASE WHEN TABLE_NAME = 'OVERALL' THEN 1 ELSE 0 END, TABLE_NAME;

-- Handy summary counts for the dashboard header tiles
SELECT
    (SELECT HEALTH_SCORE  FROM DQ_HEALTH_SCORE WHERE TABLE_NAME='OVERALL')     AS overall_trust_score,
    (SELECT COUNT(*)      FROM DQ_ISSUES WHERE STATUS='OPEN')                  AS open_issues,
    (SELECT COUNT(*)      FROM DQ_ISSUES WHERE STATUS='OPEN'
                          AND SEVERITY='CRITICAL')                            AS critical_issues,
    (SELECT BUSINESS_RISK FROM DQ_HEALTH_SCORE WHERE TABLE_NAME='OVERALL')     AS overall_business_risk;
