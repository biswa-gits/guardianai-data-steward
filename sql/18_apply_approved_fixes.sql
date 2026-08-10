-- =====================================================================
-- GuardianAI | Apply Approved Fixes - MANUAL RUNTIME RUNNER (thin)
-- =====================================================================
-- This is a convenience script to run the remediation cycle by hand from a
-- worksheet. It contains NO procedure definitions - all executor logic lives
-- in ONE place: the orchestration remediation file (single source of truth).
--
-- PREREQUISITE: full setup deployed, i.e. these procedures already exist:
--   SP_REMEDIATION_CYCLE()  -> apply approved fixes -> validate -> analyze -> log
--   (which internally uses SP_APPLY_ALL_APPROVED, RUN_APPROVED_FIXES[_NEW],
--    SP_VALIDATE_ALL, SP_ANALYZE_ALL). Defined in the orchestration files.
--
-- This mirrors EXACTLY what the Streamlit "Approve all & run remediation now"
-- button does, so manual runs and app runs stay identical.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- STEP 1 (HUMAN APPROVAL): choose ONE approval policy, then run STEP 2.
-- Responsible-AI gate: nothing executes until a row is APPROVED.
-- ---------------------------------------------------------------------

-- Option A - approve EVERYTHING (full 62 -> 100 story):
UPDATE DQ_REMEDIATION_PLAN SET APPROVAL_STATUS = 'APPROVED'
WHERE APPROVAL_STATUS = 'PENDING';

-- Option B - approve only low-risk auto-fixes (leave HIGH-risk for review):
--   UPDATE DQ_REMEDIATION_PLAN SET APPROVAL_STATUS='APPROVED'
--   WHERE APPROVAL_STATUS='PENDING' AND REQUIRES_APPROVAL = FALSE;

-- Option C - approve only critical/high severity, defer cosmetic LOW items:
--   UPDATE DQ_REMEDIATION_PLAN SET APPROVAL_STATUS='APPROVED'
--   WHERE APPROVAL_STATUS='PENDING' AND SEVERITY IN ('CRITICAL','HIGH','MEDIUM');

-- ---------------------------------------------------------------------
-- STEP 2 (EXECUTE + VALIDATE + REFRESH): one call does the whole cycle.
--   apply approved fixes (safe order, multi-statement safe, re-runnable)
--   -> re-detect + re-score (all 5 tables) -> refresh Cortex analysis
--   -> log to governance trail. Keeps every dashboard screen in sync.
-- ---------------------------------------------------------------------
CALL SP_REMEDIATION_CYCLE();

-- ---------------------------------------------------------------------
-- STEP 3 (REVIEW): confirm results.
-- ---------------------------------------------------------------------

-- Latest scores (what Page 1 shows)
SELECT * FROM DQ_HEALTH_SCORE
ORDER BY CASE WHEN TABLE_NAME = 'OVERALL' THEN 1 ELSE 0 END, TABLE_NAME;

-- What moved to quarantine (nothing deleted permanently)
SELECT 'CUSTOMERS_QUARANTINE' AS tbl, COUNT(*) AS rows1 FROM CUSTOMERS_QUARANTINE
UNION ALL SELECT 'ORDERS_QUARANTINE',    COUNT(*) FROM ORDERS_QUARANTINE
UNION ALL SELECT 'PRODUCTS_QUARANTINE',  COUNT(*) FROM PRODUCTS_QUARANTINE
UNION ALL SELECT 'PAYMENTS_QUARANTINE',  COUNT(*) FROM PAYMENTS_QUARANTINE
UNION ALL SELECT 'INVENTORY_QUARANTINE', COUNT(*) FROM INVENTORY_QUARANTINE;
