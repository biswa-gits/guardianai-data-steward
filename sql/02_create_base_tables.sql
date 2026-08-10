-- =====================================================================
-- GuardianAI | File 02: Create ALL tables (5 data + support)
-- =====================================================================
-- Data tables: CUSTOMERS, ORDERS, PRODUCTS, PAYMENTS, INVENTORY.
-- Support tables: DQ_ISSUES, DQ_HEALTH_SCORE.
-- (Quarantine + history tables live in the remediation-table file, so
--  they're created right before remediation runs - no duplication here.)
-- All columns are VARCHAR on purpose so intentionally-bad data loads
-- without being rejected; checks cast safely with TRY_TO_* later.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- DATA TABLE 1: CUSTOMERS
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID    VARCHAR,        -- VARCHAR so duplicate/blank keys can load
    CUSTOMER_NAME  VARCHAR,
    EMAIL          VARCHAR,
    PHONE          VARCHAR,
    STATE          VARCHAR,
    CREATED_DATE   VARCHAR,        -- validated/cast during checks
    SOURCE_SYSTEM  VARCHAR
);

-- ---------------------------------------------------------------------
-- DATA TABLE 2: ORDERS  (child of CUSTOMERS)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID       VARCHAR,
    CUSTOMER_ID    VARCHAR,
    ORDER_DATE     VARCHAR,
    ORDER_AMOUNT   VARCHAR,        -- allows negative/garbage values to load
    ORDER_STATUS   VARCHAR
);

-- ---------------------------------------------------------------------
-- DATA TABLE 3: PRODUCTS
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID     VARCHAR,
    PRODUCT_NAME   VARCHAR,
    CATEGORY       VARCHAR,
    PRICE          VARCHAR,        -- allows negative values to load
    ACTIVE_FLAG    VARCHAR
);

-- ---------------------------------------------------------------------
-- DATA TABLE 4: PAYMENTS  (child of ORDERS)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PAYMENTS (
    PAYMENT_ID      VARCHAR,
    ORDER_ID        VARCHAR,
    PAYMENT_DATE    VARCHAR,
    PAYMENT_AMOUNT  VARCHAR,
    PAYMENT_METHOD  VARCHAR,
    PAYMENT_STATUS  VARCHAR
);

-- ---------------------------------------------------------------------
-- DATA TABLE 5: INVENTORY  (child of PRODUCTS)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE INVENTORY (
    INVENTORY_ID    VARCHAR,
    PRODUCT_ID      VARCHAR,
    STOCK_QTY       VARCHAR,
    REORDER_LEVEL   VARCHAR,
    WAREHOUSE       VARCHAR,
    LAST_UPDATED    VARCHAR
);

-- ---------------------------------------------------------------------
-- SUPPORT TABLE: DQ_ISSUES  (one row per detected issue; Observer writes here)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE DQ_ISSUES (
    ISSUE_ID       VARCHAR DEFAULT UUID_STRING(),
    TABLE_NAME     VARCHAR,
    COLUMN_NAME    VARCHAR,
    ISSUE_TYPE     VARCHAR,
    SEVERITY       VARCHAR,        -- CRITICAL / HIGH / MEDIUM / LOW
    PENALTY        NUMBER,
    AFFECTED_ROWS  NUMBER,
    STATUS         VARCHAR DEFAULT 'OPEN',
    DETECTED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ---------------------------------------------------------------------
-- SUPPORT TABLE: DQ_HEALTH_SCORE  (one row per table + OVERALL)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE DQ_HEALTH_SCORE (
    TABLE_NAME     VARCHAR,
    TOTAL_PENALTY  NUMBER,
    HEALTH_SCORE   NUMBER,
    BUSINESS_RISK  VARCHAR,
    SCORED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SELECT 'Tables created: CUSTOMERS, ORDERS, PRODUCTS, PAYMENTS, INVENTORY, DQ_ISSUES, DQ_HEALTH_SCORE' AS status;
