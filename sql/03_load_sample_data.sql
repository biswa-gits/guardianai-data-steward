-- =====================================================================
-- GuardianAI | File 03: Load the intentionally "bad" sample data
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- Reusable CSV file format (header row, comma delimited)
CREATE OR REPLACE FILE FORMAT GUARDIANAI_CSV
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE;


CREATE OR REPLACE STAGE GUARDIANAI_STAGE FILE_FORMAT = GUARDIANAI_CSV;

COPY INTO CUSTOMERS
    FROM @GUARDIANAI_STAGE/customers_bad.csv
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV)
    ON_ERROR = 'CONTINUE';

COPY INTO ORDERS
    FROM @GUARDIANAI_STAGE/orders_bad.csv
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV)
    ON_ERROR = 'CONTINUE';

COPY INTO PRODUCTS
    FROM @GUARDIANAI_STAGE/products_bad.csv
    FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV)
    ON_ERROR = 'CONTINUE';

-- Sanity check row counts
SELECT 'CUSTOMERS' AS tbl, COUNT(*) AS rows1 FROM CUSTOMERS
UNION ALL SELECT 'ORDERS',   COUNT(*) FROM ORDERS
UNION ALL SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS;
