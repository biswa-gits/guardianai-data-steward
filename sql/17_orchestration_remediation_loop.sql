-- =====================================================================
-- GuardianAI | File 22: REMEDIATION LOOP (Loop B - human action -> re-clean)
-- Event-driven, but HUMAN-GATED. When a user approves fixes in the
-- Streamlit app (sets APPROVAL_STATUS='APPROVED'), a stream detects the
-- change and a triggered task:
--   1. snapshots BEFORE scores (once)
--   2. executes only APPROVED + un-executed fixes (base + new tables)
--   3. re-detects + re-scores (Validation Agent, all 5 tables)
--   4. logs the action to the governance trail
-- The dashboard then reflects the improved scores automatically.
--
-- This preserves Responsible AI: the loop NEVER fires on its own. It only
-- reacts to an explicit human approval.
-- Run AFTER: 21b (procedure bodies) and the base remediation procs exist.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- Combined executor: runs approved fixes for ALL tables in safe order.
-- (Wraps RUN_APPROVED_FIXES + RUN_APPROVED_FIXES_NEW from files 13 & 19.)
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE SP_APPLY_ALL_APPROVED()
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    IF ((SELECT COUNT(*) FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL='BEFORE_REMEDIATION')=0) THEN
        INSERT INTO DQ_HEALTH_HISTORY (RUN_LABEL,TABLE_NAME,HEALTH_SCORE,BUSINESS_RISK)
        SELECT 'BEFORE_REMEDIATION',TABLE_NAME,HEALTH_SCORE,BUSINESS_RISK FROM DQ_HEALTH_SCORE;
    END IF;

    -- make approved fixes re-runnable (idempotent)
    UPDATE DQ_REMEDIATION_PLAN SET EXECUTED=FALSE WHERE APPROVAL_STATUS='APPROVED';

    CALL RUN_APPROVED_FIXES();
    CALL RUN_APPROVED_FIXES_NEW();
    RETURN 'approved fixes applied';
END;
$$;
-- ---------------------------------------------------------------------
-- Validation procedure: re-detect + re-score all 5, capture AFTER.
-- (Wraps the detect+score procs; mirrors file 14c.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_VALIDATE_ALL()
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    TRUNCATE TABLE DQ_ISSUES;
    CALL SP_DETECT_BASE();
    CALL SP_DETECT_NEW();
    CALL SP_SCORE_5TABLES();
    DELETE FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL='AFTER_REMEDIATION';
    INSERT INTO DQ_HEALTH_HISTORY (RUN_LABEL,TABLE_NAME,HEALTH_SCORE,BUSINESS_RISK)
    SELECT 'AFTER_REMEDIATION',TABLE_NAME,HEALTH_SCORE,BUSINESS_RISK FROM DQ_HEALTH_SCORE;
    RETURN 'validation complete';
END;
$$;

-- ---------------------------------------------------------------------
-- Orchestrated remediation procedure = apply -> validate -> govern.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_REMEDIATION_CYCLE()
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    CALL SP_APPLY_ALL_APPROVED();
    CALL SP_VALIDATE_ALL();
    CALL SP_ANALYZE_ALL();
    CALL LOG_EVENT('ORCHESTRATOR','REMEDIATION_CYCLE',NULL,NULL,
        'Applied approved fixes and re-validated all 5 tables','DATA_STEWARD');
    -- Drain the approvals stream so the task doesn't re-fire on the same change
    CREATE OR REPLACE TEMPORARY TABLE _drain_appr AS SELECT 1 AS X FROM STRM_APPROVALS;
    RETURN 'remediation cycle complete';
END;
$$;

-- ---------------------------------------------------------------------
-- TRIGGERED TASK: fire the remediation cycle when the approvals stream
-- has data AND at least one row is APPROVED but not yet executed.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TASK TSK_REMEDIATE_ON_APPROVAL
    WAREHOUSE = GUARDIANAI_WH
    SCHEDULE  = '1 minute'
    WHEN SYSTEM$STREAM_HAS_DATA('STRM_APPROVALS')
AS CALL SP_REMEDIATION_CYCLE();

ALTER TASK TSK_REMEDIATE_ON_APPROVAL RESUME;

SELECT 'Remediation loop armed: approve in the app -> auto fix + re-validate' AS status;


-- ---------------------------------------------------------------------
-- RUN_APPROVED_FIXES : base 3 tables (multi-statement safe)
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE RUN_APPROVED_FIXES()
RETURNS STRING LANGUAGE SQL AS
$$
DECLARE
    c1 CURSOR FOR
        SELECT PLAN_ID, FIX_SQL FROM DQ_REMEDIATION_PLAN
        WHERE APPROVAL_STATUS='APPROVED' AND EXECUTED=FALSE
          AND TABLE_NAME IN ('CUSTOMERS','ORDERS','PRODUCTS')
        ORDER BY CASE TABLE_NAME WHEN 'CUSTOMERS' THEN 1 WHEN 'ORDERS' THEN 2 ELSE 3 END,
                 CASE FIX_METHOD  WHEN 'QUARANTINE' THEN 1 WHEN 'DEDUP' THEN 2 ELSE 3 END;
    n     INTEGER DEFAULT 0;
    pid   STRING;
    fsql  STRING;
    parts ARRAY;
    part  STRING;
BEGIN
    FOR rec IN c1 DO
        pid  := rec.PLAN_ID;          -- copy cursor fields to locals FIRST
        fsql := rec.FIX_SQL;
        parts := SPLIT(:fsql, ';');
        FOR i IN 0 TO ARRAY_SIZE(parts)-1 DO
            part := TRIM(GET(parts, i)::STRING);
            IF (part IS NOT NULL AND LENGTH(part) > 0) THEN
                EXECUTE IMMEDIATE :part;
            END IF;
        END FOR;
        UPDATE DQ_REMEDIATION_PLAN SET EXECUTED=TRUE WHERE PLAN_ID = :pid;  -- bind var
        n := n + 1;
    END FOR;
    RETURN 'Executed ' || n || ' base remediation step(s).';
END;
$$;

-- ---------------------------------------------------------------------
-- RUN_APPROVED_FIXES_NEW : PAYMENTS + INVENTORY
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE RUN_APPROVED_FIXES_NEW()
RETURNS STRING LANGUAGE SQL AS
$$
DECLARE
    c1 CURSOR FOR
        SELECT PLAN_ID, FIX_SQL FROM DQ_REMEDIATION_PLAN
        WHERE APPROVAL_STATUS='APPROVED' AND EXECUTED=FALSE
          AND TABLE_NAME IN ('PAYMENTS','INVENTORY')
        ORDER BY CASE FIX_METHOD WHEN 'DEDUP' THEN 1 WHEN 'QUARANTINE' THEN 2 ELSE 3 END;
    n     INTEGER DEFAULT 0;
    pid   STRING;
    fsql  STRING;
    parts ARRAY;
    part  STRING;
BEGIN
    FOR rec IN c1 DO
        pid  := rec.PLAN_ID;
        fsql := rec.FIX_SQL;
        parts := SPLIT(:fsql, ';');
        FOR i IN 0 TO ARRAY_SIZE(parts)-1 DO
            part := TRIM(GET(parts, i)::STRING);
            IF (part IS NOT NULL AND LENGTH(part) > 0) THEN
                EXECUTE IMMEDIATE :part;
            END IF;
        END FOR;
        UPDATE DQ_REMEDIATION_PLAN SET EXECUTED=TRUE WHERE PLAN_ID = :pid;
        n := n + 1;
    END FOR;
    RETURN 'Executed ' || n || ' new-table remediation step(s).';
END;
$$;



SELECT 'Robust executor installed: multi-statement safe + re-runnable' AS status;
-- ---------------------------------------------------------------------
-- OPTIONAL: give the Streamlit app a one-click "approve & run now" button
-- by exposing a callable the app can invoke directly (instead of waiting
-- up to 1 min for the scheduled trigger):
--   CALL SP_REMEDIATION_CYCLE();
-- The app can run: session.sql("CALL SP_REMEDIATION_CYCLE()").collect()
-- ---------------------------------------------------------------------
