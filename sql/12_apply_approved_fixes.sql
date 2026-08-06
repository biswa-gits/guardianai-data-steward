-- =====================================================================
-- GuardianAI | File 13: APPROVAL GATE + SAFE EXECUTION
-- Nothing here runs until a human sets APPROVAL_STATUS='APPROVED'.
-- Low-risk AUTO_FIX items can be auto-approved; HIGH-risk QUARANTINE items
-- must be approved manually. This is the Responsible-AI heart of GuardianAI.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- STEP A: Snapshot the CURRENT (before) scores so we can prove the jump later.
DELETE FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL = 'BEFORE_REMEDIATION';
INSERT INTO DQ_HEALTH_HISTORY (RUN_LABEL, TABLE_NAME, HEALTH_SCORE, BUSINESS_RISK)
SELECT 'BEFORE_REMEDIATION', TABLE_NAME, HEALTH_SCORE, BUSINESS_RISK
FROM DQ_HEALTH_SCORE;

-- ---------------------------------------------------------------------
-- STEP B: HUMAN APPROVAL
-- Option 1 - auto-approve only the low-risk items that don't need a human:
UPDATE DQ_REMEDIATION_PLAN
SET APPROVAL_STATUS = 'APPROVED'
WHERE REQUIRES_APPROVAL = FALSE;

-- Option 2 - a human approves the rest (edit this list in the demo).
-- Approve everything for the full 43 -> high-90s story:
UPDATE DQ_REMEDIATION_PLAN
SET APPROVAL_STATUS = 'APPROVED'
WHERE REQUIRES_APPROVAL = TRUE;
-- (To tell a partial-approval story instead, replace the line above with a
--  filter, e.g. WHERE SEVERITY IN ('CRITICAL','HIGH'), and leave the rest PENDING.)

-- ---------------------------------------------------------------------
-- STEP C: EXECUTE approved fixes in a SAFE ORDER using a stored procedure.
-- Order matters: clean CUSTOMERS fully first, THEN ORDERS (so orphan
-- detection runs against the cleaned customer set), THEN PRODUCTS.
-- We run each approved FIX_SQL statement dynamically.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE RUN_APPROVED_FIXES()
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
    var rows = snowflake.execute({
        sqlText: `
            SELECT PLAN_ID, FIX_SQL
            FROM DQ_REMEDIATION_PLAN
            WHERE APPROVAL_STATUS = 'APPROVED' AND EXECUTED = FALSE
            ORDER BY
                CASE TABLE_NAME WHEN 'CUSTOMERS' THEN 1
                                WHEN 'ORDERS'    THEN 2 ELSE 3 END,
                CASE FIX_METHOD WHEN 'QUARANTINE' THEN 1
                                WHEN 'DEDUP'      THEN 2 ELSE 3 END`
    });

    var n = 0;
    while (rows.next()) {
        var planId = rows.getColumnValue('PLAN_ID');
        var fixSql  = rows.getColumnValue('FIX_SQL');

        // Split on ';' so multi-statement FIX_SQL values work with the
        // single-statement-per-call restriction.
        fixSql.split(';').forEach(function(stmt) {
            stmt = stmt.trim();
            if (stmt.length > 0) {
                snowflake.execute({ sqlText: stmt });
            }
        });

        snowflake.execute({
            sqlText: 'UPDATE DQ_REMEDIATION_PLAN SET EXECUTED = TRUE WHERE PLAN_ID = ?',
            binds: [planId]
        });
        n++;
    }

    return 'Executed ' + n + ' approved remediation step(s).';
$$;

CALL RUN_APPROVED_FIXES();



-- STEP A: human approval for the new-table plan rows.
-- Auto-approve low-risk items; approve the rest for the full story.
UPDATE DQ_REMEDIATION_PLAN SET APPROVAL_STATUS='APPROVED'
WHERE TABLE_NAME IN ('PAYMENTS','INVENTORY') AND REQUIRES_APPROVAL=FALSE;

UPDATE DQ_REMEDIATION_PLAN SET APPROVAL_STATUS='APPROVED'
WHERE TABLE_NAME IN ('PAYMENTS','INVENTORY') AND REQUIRES_APPROVAL=TRUE;
-- (For a partial-approval demo, filter the line above, e.g. leave
--  INVALID_WAREHOUSE / a LOW item as PENDING.)

-- STEP B: execute approved new-table fixes in the correct method order.
CREATE OR REPLACE PROCEDURE RUN_APPROVED_FIXES_NEW()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    c1 CURSOR FOR
        SELECT PLAN_ID, FIX_SQL
        FROM DQ_REMEDIATION_PLAN
        WHERE TABLE_NAME IN ('PAYMENTS','INVENTORY')
          AND APPROVAL_STATUS = 'APPROVED'
          AND EXECUTED = FALSE
        ORDER BY
            CASE FIX_METHOD WHEN 'DEDUP' THEN 1
                            WHEN 'QUARANTINE' THEN 2
                            ELSE 3 END;
    n INTEGER DEFAULT 0;
BEGIN
    FOR rec IN c1 DO
        EXECUTE IMMEDIATE rec.FIX_SQL;   -- handles single & INSERT;DELETE pairs
        UPDATE DQ_REMEDIATION_PLAN SET EXECUTED = TRUE WHERE PLAN_ID = rec.PLAN_ID;
        n := n + 1;
    END FOR;
    RETURN 'Executed ' || n || ' approved new-table remediation step(s).';
END;
$$;

CALL RUN_APPROVED_FIXES_NEW();


-- Quick look at what moved to quarantine (nothing was deleted permanently)
SELECT 'CUSTOMERS_QUARANTINE' AS tbl, COUNT(*) AS rows1 FROM CUSTOMERS_QUARANTINE
UNION ALL SELECT 'ORDERS_QUARANTINE', COUNT(*) FROM ORDERS_QUARANTINE
UNION ALL SELECT 'PRODUCTS_QUARANTINE', COUNT(*) FROM PRODUCTS_QUARANTINE;

-- What moved to quarantine (nothing deleted permanently)
SELECT 'PAYMENTS_QUARANTINE'  AS tbl, COUNT(*) AS rows1 FROM PAYMENTS_QUARANTINE
UNION ALL SELECT 'INVENTORY_QUARANTINE', COUNT(*) FROM INVENTORY_QUARANTINE;

-- Remaining row counts after remediation
SELECT 'PAYMENTS' AS tbl, COUNT(*) AS rows1 FROM PAYMENTS
UNION ALL SELECT 'INVENTORY', COUNT(*) FROM INVENTORY;
