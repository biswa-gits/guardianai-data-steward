-- =====================================================================
-- GuardianAI | File 02: Create the three retail tables + supporting tables
-- Data model per strategy brief Section 11 (CUSTOMERS, ORDERS, PRODUCTS)
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- Table 1: CUSTOMERS
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID    VARCHAR,        -- kept as VARCHAR so we can load duplicate/blank keys
    CUSTOMER_NAME  VARCHAR,
    EMAIL          VARCHAR,
    PHONE          VARCHAR,
    STATE          VARCHAR,
    CREATED_DATE   VARCHAR,        -- loaded as string; we validate/cast during checks
    SOURCE_SYSTEM  VARCHAR
);

-- ---------------------------------------------------------------------
-- Table 2: ORDERS
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID       VARCHAR,
    CUSTOMER_ID    VARCHAR,
    ORDER_DATE     VARCHAR,
    ORDER_AMOUNT   VARCHAR,        -- string on purpose to allow negative/garbage values
    ORDER_STATUS   VARCHAR
);

-- ---------------------------------------------------------------------
-- Table 3: PRODUCTS
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID     VARCHAR,
    PRODUCT_NAME   VARCHAR,
    CATEGORY       VARCHAR,
    PRICE          VARCHAR,        -- string on purpose to allow negative values
    ACTIVE_FLAG    VARCHAR
);

-- ---------------------------------------------------------------------
-- Supporting table: DQ_ISSUES  (one row per detected issue)
-- This is what the Data Observer Agent writes into.
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
-- Supporting table: DQ_HEALTH_SCORE (one row per table + overall)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE DQ_HEALTH_SCORE (
    TABLE_NAME     VARCHAR,
    TOTAL_PENALTY  NUMBER,
    HEALTH_SCORE   NUMBER,
    BUSINESS_RISK  VARCHAR,
    SCORED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SELECT 'Tables created: CUSTOMERS, ORDERS, PRODUCTS, DQ_ISSUES, DQ_HEALTH_SCORE' AS status;
