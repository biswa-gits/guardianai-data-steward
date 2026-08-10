-- =====================================================================
-- GuardianAI | Health Score model (VOLUME-AWARE, all 5 tables)
-- =====================================================================
--
-- MODEL (hybrid: severity + how widespread):
--   penalty_per_issue = PRESENCE(severity) + VOLUME_MULT(severity) * pct_rows_affected
--   table_health      = GREATEST(0, 100 - SUM(penalty_per_issue))
--   overall           = AVG(table health scores)
--
-- Why hybrid:
--   * PRESENCE  = a fixed cost for the issue existing at all (a broken
--                 foreign key or duplicate PK is serious even at low volume).
--   * VOLUME    = scales with how widespread the issue is (500 bad rows > 5).
-- Fully deterministic and bounded 0-100.
--
-- Weights (keep identical anywhere scoring is recomputed, e.g. SP_SCORE_5TABLES):
--   PRESENCE:     CRITICAL 8  | HIGH 4  | MEDIUM 2   | LOW 1
--   VOLUME_MULT:  CRITICAL 1.5| HIGH 1.0| MEDIUM 0.7 | LOW 0.3   (points per 1% of rows)
--
-- Prerequisite: run detection first (base + new tables) so DQ_ISSUES is populated.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

TRUNCATE TABLE DQ_HEALTH_SCORE;

-- ---------------------------------------------------------------------
-- Per-table score = 100 - SUM(weighted penalty), floored at 0.
-- table_stats gives live row counts (for the % affected calculation).
-- ---------------------------------------------------------------------
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
WITH table_stats AS (
    SELECT 'CUSTOMERS' AS TABLE_NAME, COUNT(*) AS TOTAL_ROWS FROM CUSTOMERS
    UNION ALL SELECT 'ORDERS',    COUNT(*) FROM ORDERS
    UNION ALL SELECT 'PRODUCTS',  COUNT(*) FROM PRODUCTS
    UNION ALL SELECT 'PAYMENTS',  COUNT(*) FROM PAYMENTS
    UNION ALL SELECT 'INVENTORY', COUNT(*) FROM INVENTORY
),
scored AS (
    SELECT
        i.TABLE_NAME,
        -- Presence cost (fixed, by severity)
        CASE i.SEVERITY WHEN 'CRITICAL' THEN 8 WHEN 'HIGH' THEN 4
                        WHEN 'MEDIUM'   THEN 2 ELSE 1 END
        -- Volume cost (points per 1% of rows affected, by severity)
        + CASE i.SEVERITY WHEN 'CRITICAL' THEN 1.5 WHEN 'HIGH' THEN 1.0
                          WHEN 'MEDIUM'   THEN 0.7 ELSE 0.3 END
          * (100.0 * i.AFFECTED_ROWS / NULLIF(s.TOTAL_ROWS, 0)) AS ISSUE_PENALTY
    FROM DQ_ISSUES i
    JOIN table_stats s ON s.TABLE_NAME = i.TABLE_NAME
    WHERE i.STATUS = 'OPEN'
)
SELECT
    TABLE_NAME,
    ROUND(SUM(ISSUE_PENALTY), 1)                    AS TOTAL_PENALTY,
    GREATEST(0, ROUND(100 - SUM(ISSUE_PENALTY)))    AS HEALTH_SCORE,
    CASE
        WHEN GREATEST(0, 100 - SUM(ISSUE_PENALTY)) >= 90 THEN 'LOW'
        WHEN GREATEST(0, 100 - SUM(ISSUE_PENALTY)) >= 75 THEN 'MEDIUM'
        WHEN GREATEST(0, 100 - SUM(ISSUE_PENALTY)) >= 50 THEN 'HIGH'
        ELSE 'CRITICAL'
    END                                             AS BUSINESS_RISK
FROM scored
GROUP BY TABLE_NAME;

-- ---------------------------------------------------------------------
-- Any of the 5 tables with zero open issues won't appear above -> add at 100.
-- ---------------------------------------------------------------------
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
SELECT t.TABLE_NAME, 0, 100, 'LOW'
FROM (SELECT 'CUSTOMERS' TABLE_NAME UNION ALL SELECT 'ORDERS' UNION ALL SELECT 'PRODUCTS'
      UNION ALL SELECT 'PAYMENTS' UNION ALL SELECT 'INVENTORY') t
WHERE t.TABLE_NAME NOT IN (SELECT TABLE_NAME FROM DQ_HEALTH_SCORE);

-- ---------------------------------------------------------------------
-- Overall trust score = average of the 5 table scores.
-- ---------------------------------------------------------------------
INSERT INTO DQ_HEALTH_SCORE (TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK)
SELECT 'OVERALL', ROUND(SUM(TOTAL_PENALTY), 1), ROUND(AVG(HEALTH_SCORE)),
    CASE
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 90 THEN 'LOW'
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 75 THEN 'MEDIUM'
        WHEN ROUND(AVG(HEALTH_SCORE)) >= 50 THEN 'HIGH'
        ELSE 'CRITICAL'
    END
FROM DQ_HEALTH_SCORE
WHERE TABLE_NAME <> 'OVERALL';

-- ---------------------------------------------------------------------
-- Scoreboard (this is what Page 1 "Data Trust Overview" reads).
-- ---------------------------------------------------------------------
SELECT TABLE_NAME, TOTAL_PENALTY, HEALTH_SCORE, BUSINESS_RISK, SCORED_AT
FROM DQ_HEALTH_SCORE
ORDER BY CASE WHEN TABLE_NAME = 'OVERALL' THEN 1 ELSE 0 END, TABLE_NAME;
