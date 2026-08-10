-- =====================================================================
-- GuardianAI | File 13: ORCHESTRATION SETUP (event-driven pipeline)
-- Sets up the plumbing for automatic ingest + change detection:
--   * A stage with a DIRECTORY TABLE (so Snowflake "sees" dropped files)
--   * Auto-ingest COPY via Snowpipe (or a triggered task fallback)
--   * STREAMS on the 5 tables (change-data-capture) so we know when new
--     rows arrive and can run the pipeline only when there's work to do.
--
-- NOTE ON TRIAL ACCOUNTS:
--   * Streams + Tasks work on standard/trial accounts.
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- 1) Landing stage with a DIRECTORY TABLE (tracks files that land here)
-- ---------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS GUARDIANAI_LANDING
    DIRECTORY = (ENABLE = TRUE)
    FILE_FORMAT = GUARDIANAI_CSV;

-- Convention: drop files named by target table, e.g.
--   customers_*.csv, orders_*.csv, products_*.csv,
--   payments_*.csv,  inventory_*.csv
-- into @GUARDIANAI_LANDING. New batches = new rows appended.

-- Refresh the directory listing (do this after any manual PUT)
ALTER STAGE GUARDIANAI_LANDING REFRESH;

-- ---------------------------------------------------------------------
-- 2) STREAMS for change-data-capture on each table.
--    A stream records rows added since it was last consumed. We use
--    SYSTEM$STREAM_HAS_DATA(...) to trigger the pipeline only when needed.
-- ---------------------------------------------------------------------
CREATE OR REPLACE STREAM STRM_CUSTOMERS ON TABLE CUSTOMERS APPEND_ONLY = TRUE;
CREATE OR REPLACE STREAM STRM_ORDERS    ON TABLE ORDERS    APPEND_ONLY = TRUE;
CREATE OR REPLACE STREAM STRM_PRODUCTS  ON TABLE PRODUCTS  APPEND_ONLY = TRUE;
CREATE OR REPLACE STREAM STRM_PAYMENTS  ON TABLE PAYMENTS  APPEND_ONLY = TRUE;
CREATE OR REPLACE STREAM STRM_INVENTORY ON TABLE INVENTORY APPEND_ONLY = TRUE;

-- ---------------------------------------------------------------------
-- 3) STREAM on the remediation plan's approval column, for Loop B.
--    Fires the "execute approved fixes" task when a human approves.
--    (Standard stream so UPDATES to APPROVAL_STATUS are captured.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE STREAM STRM_APPROVALS ON TABLE DQ_REMEDIATION_PLAN;

-- ---------------------------------------------------------------------
-- 4) Snowpipe for auto-ingest (use if your stage is backed by cloud
--    storage with notifications; otherwise use the triggered-task ingest
--    in file 21). One pipe per table keeps loads clean.
-- ---------------------------------------------------------------------
CREATE PIPE IF NOT EXISTS PIPE_CUSTOMERS AUTO_INGEST = TRUE AS
    COPY INTO CUSTOMERS FROM @GUARDIANAI_LANDING
    PATTERN = '.*customers_.*[.]csv' FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR='CONTINUE';
CREATE PIPE IF NOT EXISTS PIPE_ORDERS AUTO_INGEST = TRUE AS
    COPY INTO ORDERS FROM @GUARDIANAI_LANDING
    PATTERN = '.*orders_.*[.]csv' FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR='CONTINUE';
CREATE PIPE IF NOT EXISTS PIPE_PRODUCTS AUTO_INGEST = TRUE AS
    COPY INTO PRODUCTS FROM @GUARDIANAI_LANDING
    PATTERN = '.*products_.*[.]csv' FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR='CONTINUE';
CREATE PIPE IF NOT EXISTS PIPE_PAYMENTS AUTO_INGEST = TRUE AS
    COPY INTO PAYMENTS FROM @GUARDIANAI_LANDING
    PATTERN = '.*payments_.*[.]csv' FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR='CONTINUE';
CREATE PIPE IF NOT EXISTS PIPE_INVENTORY AUTO_INGEST = TRUE AS
    COPY INTO INVENTORY FROM @GUARDIANAI_LANDING
    PATTERN = '.*inventory_.*[.]csv' FILE_FORMAT = (FORMAT_NAME = GUARDIANAI_CSV) ON_ERROR='CONTINUE';

SELECT 'Orchestration setup ready: landing stage, streams, approval stream, pipes' AS status;
