-- =====================================================================
-- GuardianAI | File 16: NEW TABLES (Step 3 - scope expansion)
--   PAYMENTS   -> child of ORDERS
--   INVENTORY  -> child of PRODUCTS
-- Same VARCHAR-on-load pattern so bad data isn't rejected at load time.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- PAYMENTS  (references ORDERS.ORDER_ID)
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
-- INVENTORY  (references PRODUCTS.PRODUCT_ID)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE INVENTORY (
    INVENTORY_ID    VARCHAR,
    PRODUCT_ID      VARCHAR,
    STOCK_QTY       VARCHAR,
    REORDER_LEVEL   VARCHAR,
    WAREHOUSE       VARCHAR,
    LAST_UPDATED    VARCHAR
);

-- Quarantine tables (remediation moves bad rows here, never deletes)
CREATE OR REPLACE TABLE PAYMENTS_QUARANTINE  LIKE PAYMENTS;
CREATE OR REPLACE TABLE INVENTORY_QUARANTINE LIKE INVENTORY;

SELECT 'PAYMENTS, INVENTORY (+ quarantine) tables created' AS status;
