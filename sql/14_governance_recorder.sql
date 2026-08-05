-- =====================================================================
-- GuardianAI | File 15: GOVERNANCE RECORDER AGENT (Day 4)
-- Maintains a single immutable-style audit trail of everything the
-- system did: detection, diagnosis, recommendation, approval, execution,
-- validation. This powers Page 5 (Governance Log) and is the backbone
-- of the Responsible-AI story (15% weight).
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- One append-only log table for the whole agentic lifecycle
CREATE TABLE IF NOT EXISTS DQ_GOVERNANCE_LOG (
    LOG_ID       VARCHAR DEFAULT UUID_STRING(),
    EVENT_TIME   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    AGENT        VARCHAR,     -- OBSERVER / DIAGNOSIS / IMPACT / REMEDIATION / VALIDATION / GOVERNANCE
    ACTION       VARCHAR,     -- what happened
    TABLE_NAME   VARCHAR,
    ISSUE_TYPE   VARCHAR,
    DETAIL       VARCHAR,     -- human-readable detail
    ACTOR        VARCHAR      -- 'SYSTEM' or the approver's role/name
);

-- ---------------------------------------------------------------------
-- Reusable procedure so any step can write to the log in one line.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE LOG_EVENT(
    P_AGENT VARCHAR, P_ACTION VARCHAR, P_TABLE VARCHAR,
    P_ISSUE VARCHAR, P_DETAIL VARCHAR, P_ACTOR VARCHAR)
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
    VALUES (:P_AGENT, :P_ACTION, :P_TABLE, :P_ISSUE, :P_DETAIL, :P_ACTOR);
    RETURN 'logged';
END;
$$;

-- ---------------------------------------------------------------------
-- Backfill the log from the work already done (so the demo has history).
-- In a live system each agent would call LOG_EVENT() as it runs.
-- ---------------------------------------------------------------------

-- 1) Detection events (Observer Agent) - from analysis table (pre-remediation set)
INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'OBSERVER','ISSUE_DETECTED', TABLE_NAME, ISSUE_TYPE,
       AFFECTED_ROWS || ' row(s) flagged as ' || SEVERITY, 'SYSTEM'
FROM DQ_ISSUE_ANALYSIS;

-- 2) Diagnosis + Impact events
INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'DIAGNOSIS','ROOT_CAUSE_GENERATED', TABLE_NAME, ISSUE_TYPE,
       LEFT(ROOT_CAUSE, 200), 'SYSTEM'
FROM DQ_ISSUE_ANALYSIS WHERE ROOT_CAUSE IS NOT NULL;

INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'IMPACT','BUSINESS_IMPACT_ASSESSED', TABLE_NAME, ISSUE_TYPE,
       LEFT(BUSINESS_IMPACT, 200), 'SYSTEM'
FROM DQ_ISSUE_ANALYSIS WHERE BUSINESS_IMPACT IS NOT NULL;

-- 3) Remediation recommendation + approval + execution events
INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'REMEDIATION','FIX_RECOMMENDED', TABLE_NAME, ISSUE_TYPE,
       'Method=' || FIX_METHOD || ', confidence=' || CONFIDENCE ||
       '%, risk=' || RISK_LEVEL, 'SYSTEM'
FROM DQ_REMEDIATION_PLAN;

INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'GOVERNANCE',
       CASE WHEN APPROVAL_STATUS='APPROVED' THEN 'FIX_APPROVED'
            WHEN APPROVAL_STATUS='REJECTED' THEN 'FIX_REJECTED'
            ELSE 'FIX_PENDING_APPROVAL' END,
       TABLE_NAME, ISSUE_TYPE,
       'Approval status: ' || APPROVAL_STATUS ||
       CASE WHEN REQUIRES_APPROVAL THEN ' (human review required)' ELSE ' (auto, low risk)' END,
       CASE WHEN REQUIRES_APPROVAL THEN 'DATA_STEWARD' ELSE 'SYSTEM' END
FROM DQ_REMEDIATION_PLAN;

INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'REMEDIATION','FIX_EXECUTED', TABLE_NAME, ISSUE_TYPE,
       'Executed ' || FIX_METHOD || ' fix', 'SYSTEM'
FROM DQ_REMEDIATION_PLAN WHERE EXECUTED = TRUE;

-- 4) Validation event - the before/after outcome
INSERT INTO DQ_GOVERNANCE_LOG (AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR)
SELECT 'VALIDATION','SCORE_VALIDATED', a.TABLE_NAME, NULL,
       'Health score ' || b.HEALTH_SCORE || ' -> ' || a.HEALTH_SCORE ||
       ' (' || b.BUSINESS_RISK || ' -> ' || a.BUSINESS_RISK || ')', 'SYSTEM'
FROM      (SELECT * FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL='AFTER_REMEDIATION')  a
LEFT JOIN (SELECT * FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL='BEFORE_REMEDIATION') b
       ON a.TABLE_NAME = b.TABLE_NAME;

-- Full audit trail, newest first (Page 5 view)
SELECT EVENT_TIME, AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR
FROM DQ_GOVERNANCE_LOG
ORDER BY EVENT_TIME DESC, AGENT;
