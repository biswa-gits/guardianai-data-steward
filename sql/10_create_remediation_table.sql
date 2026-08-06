-- =====================================================================
-- GuardianAI | File 11: Remediation storage (Day 3 - the agentic loop)
-- Holds the fix PLAN: recommended action, generated fix SQL, confidence,
-- risk, and the human-approval gate. Nothing executes from here directly.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

CREATE OR REPLACE TABLE DQ_REMEDIATION_PLAN (
    PLAN_ID          VARCHAR DEFAULT UUID_STRING(),
    ISSUE_ID         VARCHAR,          -- FK to DQ_ISSUES
    TABLE_NAME       VARCHAR,
    ISSUE_TYPE       VARCHAR,
    SEVERITY         VARCHAR,
    AFFECTED_ROWS    NUMBER,
    RECOMMENDED_ACTION VARCHAR,        -- AI-narrated plain-English recommendation
    FIX_METHOD       VARCHAR,          -- AUTO_FIX / DEDUP / QUARANTINE
    FIX_SQL          VARCHAR,          -- the deterministic SQL that will run
    CONFIDENCE       NUMBER,           -- 0-100
    RISK_LEVEL       VARCHAR,          -- LOW / MEDIUM / HIGH
    REQUIRES_APPROVAL BOOLEAN,
    APPROVAL_STATUS  VARCHAR DEFAULT 'PENDING',  -- PENDING/APPROVED/REJECTED
    EXECUTED         BOOLEAN DEFAULT FALSE,
    CREATED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Quarantine tables: we never delete blindly. Bad rows move here for review.
CREATE OR REPLACE TABLE CUSTOMERS_QUARANTINE LIKE CUSTOMERS;
CREATE OR REPLACE TABLE ORDERS_QUARANTINE    LIKE ORDERS;
CREATE OR REPLACE TABLE PRODUCTS_QUARANTINE  LIKE PRODUCTS;
CREATE OR REPLACE TABLE PAYMENTS_QUARANTINE  LIKE PAYMENTS;
CREATE OR REPLACE TABLE INVENTORY_QUARANTINE LIKE INVENTORY;
-- History of health scores so we can prove before -> after
CREATE OR REPLACE TABLE DQ_HEALTH_HISTORY (
    RUN_LABEL     VARCHAR,       -- e.g. 'BEFORE_REMEDIATION' / 'AFTER_REMEDIATION'
    TABLE_NAME    VARCHAR,
    HEALTH_SCORE  NUMBER,
    BUSINESS_RISK VARCHAR,
    CAPTURED_AT   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SELECT 'Remediation + quarantine + history tables ready' AS status;
