-- =====================================================================
-- GuardianAI | File 03: Load data  (REFERENCE - optional)
-- =====================================================================
--
-- NOTE: In this project the LARGE CSVs are loaded via the Snowsight UI
--       (Data > table > Load Data). This file is kept as a reference /
--       scripted alternative. Run it only if you prefer COPY over the UI.
--
-- File naming convention used by the orchestration landing stage later:
--   customers_*.csv, orders_*.csv, products_*.csv, payments_*.csv, inventory_*.csv
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- Reusable CSV file format (header row, comma delimited, blanks -> NULL)
CREATE OR REPLACE FILE FORMAT GUARDIANAI_CSV
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE;

-- Internal stage for scripted PUT + COPY (skip if using the UI)
CREATE OR REPLACE STAGE GUARDIANAI_STAGE FILE_FORMAT = GUARDIANAI_CSV;

-- ---------------------------------------------------------------------
-- Optional scripted load (from SnowSQL CLI):
--   PUT file://.../customers_large.csv  @GUARDIANAI_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://.../orders_large.csv     @GUARDIANAI_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://.../products_large.csv   @GUARDIANAI_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://.../payments_large.csv   @GUARDIANAI_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://.../inventory_large.csv  @GUARDIANAI_STAGE AUTO_COMPRESS=TRUE;
-- Then COPY each into its table:
-- ---------------------------------------------------------------------
COPY INTO CUSTOMERS FROM @GUARDIANAI_STAGE PATTERN='.*customers_.*[.]csv'
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR = 'CONTINUE';
COPY INTO ORDERS    FROM @GUARDIANAI_STAGE PATTERN='.*orders_.*[.]csv'
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR = 'CONTINUE';
COPY INTO PRODUCTS  FROM @GUARDIANAI_STAGE PATTERN='.*products_.*[.]csv'
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR = 'CONTINUE';
COPY INTO PAYMENTS  FROM @GUARDIANAI_STAGE PATTERN='.*payments_.*[.]csv'
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR = 'CONTINUE';
COPY INTO INVENTORY FROM @GUARDIANAI_STAGE PATTERN='.*inventory_.*[.]csv'
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR = 'CONTINUE';

-- Row-count sanity check (works whether loaded via UI or COPY)
SELECT 'CUSTOMERS' AS tbl, COUNT(*) AS rows1 FROM CUSTOMERS
UNION ALL SELECT 'ORDERS',    COUNT(*) FROM ORDERS
UNION ALL SELECT 'PRODUCTS',  COUNT(*) FROM PRODUCTS
UNION ALL SELECT 'PAYMENTS',  COUNT(*) FROM PAYMENTS
UNION ALL SELECT 'INVENTORY', COUNT(*) FROM INVENTORY;
