-- =====================================================================
-- GuardianAI | File 05b: VOLUME-AWARE HEALTH SCORE  (upgraded scoring)
-- Replaces the flat per-issue penalty from file 05 with a hybrid model
-- that respects BOTH issue severity AND the % of rows affected.
--
-- MODEL:
--   penalty_per_issue = PRESENCE(severity) + VOLUME_MULT(severity) * pct_rows_affected
--   table_health      = GREATEST(0, 100 - SUM(penalty_per_issue))
--
-- Rationale:
--   * PRESENCE  = a fixed cost for the issue existing at all (a broken foreign
--                 key or duplicate PK is serious even at low volume).
--   * VOLUME    = scales with how widespread the issue is (500 bad rows > 5).
-- This makes big datasets actually drive the score, while keeping severity
-- meaningful. Fully deterministic and bounded 0-100.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

TRUNCATE TABLE DQ_HEALTH_SCORE;

-- ---------------------------------------------------------------------
-- Roll up to a per-table health score.
-- ---------------------------------------------------------------------
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
-- ---------------------------------------------------------------------
-- Live row totals per table (used to compute % affected).
-- ---------------------------------------------------------------------
WITH table_stats AS (
    SELECT 'CUSTOMERS' AS TABLE_NAME, COUNT(*) AS TOTAL_ROWS FROM CUSTOMERS
    UNION ALL SELECT 'ORDERS',   COUNT(*) FROM ORDERS
    UNION ALL SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
),
-- ---------------------------------------------------------------------
-- Per-issue weighted penalty using the hybrid model.
-- ---------------------------------------------------------------------
scored AS (
    SELECT
        i.TABLE_NAME,
        i.ISSUE_TYPE,
        i.SEVERITY,
        i.AFFECTED_ROWS,
        s.TOTAL_ROWS,
        100.0 * i.AFFECTED_ROWS / NULLIF(s.TOTAL_ROWS, 0) AS PCT_AFFECTED,
        -- Presence cost (fixed, by severity)
        CASE i.SEVERITY WHEN 'CRITICAL' THEN 8 WHEN 'HIGH' THEN 4
                        WHEN 'MEDIUM'   THEN 2 ELSE 1 END
        +
        -- Volume cost (points per 1% of rows affected, by severity)
        CASE i.SEVERITY WHEN 'CRITICAL' THEN 1.5 WHEN 'HIGH' THEN 1.0
                        WHEN 'MEDIUM'   THEN 0.7 ELSE 0.3 END
        * (100.0 * i.AFFECTED_ROWS / NULLIF(s.TOTAL_ROWS, 0))   AS ISSUE_PENALTY
    FROM DQ_ISSUES i
    JOIN table_stats s ON s.TABLE_NAME = i.TABLE_NAME
    WHERE i.STATUS = 'OPEN'
)
SELECT
    TABLE_NAME,
    ROUND(SUM(ISSUE_PENALTY), 1)                       AS TOTAL_PENALTY,
    GREATEST(0, ROUND(100 - SUM(ISSUE_PENALTY)))       AS HEALTH_SCORE,
    CASE
        WHEN GREATEST(0, 100 - SUM(ISSUE_PENALTY)) >= 90 THEN 'LOW'
        WHEN GREATEST(0, 100 - SUM(ISSUE_PENALTY)) >= 75 THEN 'MEDIUM'
        WHEN GREATEST(0, 100 - SUM(ISSUE_PENALTY)) >= 50 THEN 'HIGH'
        ELSE 'CRITICAL'
    END                                                AS BUSINESS_RISK
FROM scored
GROUP BY TABLE_NAME;

-- Tables with zero open issues won't appear above -> add them back at 100.
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
SELECT t.TABLE_NAME, 0, 100, 'LOW'
FROM (SELECT 'CUSTOMERS' TABLE_NAME UNION ALL SELECT 'ORDERS' UNION ALL SELECT 'PRODUCTS') t
WHERE t.TABLE_NAME NOT IN (SELECT TABLE_NAME FROM DQ_HEALTH_SCORE);

-- ---------------------------------------------------------------------
-- Overall trust score = average of table scores.
-- ---------------------------------------------------------------------
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
SELECT 'OVERALL', ROUND(SUM(TOTAL_PENALTY),1), ROUND(AVG(HEALTH_SCORE)),
    CASE
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 90 THEN 'LOW'
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 75 THEN 'MEDIUM'
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 50 THEN 'HIGH'
        ELSE 'CRITICAL'
    END
FROM DQ_HEALTH_SCORE WHERE TABLE_NAME <> 'OVERALL';

-- ---------------------------------------------------------------------
-- Scoreboard + a detailed per-issue penalty breakdown (great for the demo).
-- ---------------------------------------------------------------------
SELECT TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK, SCORED_AT
FROM DQ_HEALTH_SCORE
ORDER BY CASE WHEN TABLE_NAME='OVERALL' THEN 1 ELSE 0 END, TABLE_NAME;

-- Optional: show how each issue contributed (uncomment to inspect)
-- WITH table_stats AS (
--     SELECT 'CUSTOMERS' TABLE_NAME, COUNT(*) TOTAL_ROWS FROM CUSTOMERS
--     UNION ALL SELECT 'ORDERS', COUNT(*) FROM ORDERS
--     UNION ALL SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS)
-- SELECT i.TABLE_NAME, i.ISSUE_TYPE, i.SEVERITY, i.AFFECTED_ROWS, s.TOTAL_ROWS,
--        ROUND(100.0*i.AFFECTED_ROWS/s.TOTAL_ROWS,2) AS PCT_AFFECTED
-- FROM DQ_ISSUES i JOIN table_stats s ON s.TABLE_NAME=i.TABLE_NAME
-- WHERE i.STATUS='OPEN' ORDER BY i.TABLE_NAME, PCT_AFFECTED DESC;
