-- =====================================================================
-- GuardianAI | File 21: DETECTION TASK GRAPH (Loop A - ingest -> detect)
-- Builds the automated pipeline that runs when new rows arrive:
--   T0  INGEST (triggered-task fallback for internal stages)
--   T1  DETECT      (Observer Agent, all 5 tables)          <- root
--   T2  SCORE       (volume-aware, all 5 tables)
--   T3  ANALYZE     (Cortex diagnosis + impact + exec summary)
--   T4  GOVERN      (log the automated run)
-- Tasks are chained into a DAG. The root uses a WHEN clause so the graph
-- only runs when at least one stream has new data (cost-efficient).
--
-- Wrap the detection/scoring/analysis SQL you already have into procedures
-- so tasks can call them in one line. (Bodies mirror files 04/17, 05c, 07-09.)
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- 0) INGEST fallback (for internal-stage trial accounts without Snowpipe
--    notifications). Refreshes the directory and COPYs any new files.
--    Streams on the tables will then reflect the newly loaded rows.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_INGEST_LANDING()
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    ALTER STAGE GUARDIANAI_LANDING REFRESH;
    COPY INTO CUSTOMERS FROM @GUARDIANAI_LANDING PATTERN='.*customers_.*[.]csv'
        FILE_FORMAT=(FORMAT_NAME=GUARDIANAI_CSV) ON_ERROR='CONTINUE';
    COPY INTO ORDERS    FROM @GUARDIANAI_LANDING PATTERN='.*orders_.*[.]csv'
        FILE_FORMAT=(FORMAT_NAME=GUARDIANAI_CSV) ON_ERROR='CONTINUE';
    COPY INTO PRODUCTS  FROM @GUARDIANAI_LANDING PATTERN='.*products_.*[.]csv'
        FILE_FORMAT=(FORMAT_NAME=GUARDIANAI_CSV) ON_ERROR='CONTINUE';
    COPY INTO PAYMENTS  FROM @GUARDIANAI_LANDING PATTERN='.*payments_.*[.]csv'
        FILE_FORMAT=(FORMAT_NAME=GUARDIANAI_CSV) ON_ERROR='CONTINUE';
    COPY INTO INVENTORY FROM @GUARDIANAI_LANDING PATTERN='.*inventory_.*[.]csv'
        FILE_FORMAT=(FORMAT_NAME=GUARDIANAI_CSV) ON_ERROR='CONTINUE';
    RETURN 'ingest complete';
END;
$$;

-- ---------------------------------------------------------------------
-- 1) DETECT procedure = the Observer Agent for all 5 tables.
--    (This is the exact detection logic from files 04 + 17, wrapped up.)
--    Consumes the streams so they reset for the next batch.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_DETECT_ALL()
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    TRUNCATE TABLE DQ_ISSUES;
    -- NOTE: paste the full INSERT...SELECT detection blocks from file 04
    -- (base 3 tables) and file 17 (PAYMENTS + INVENTORY) here.
    -- Kept as a call-out to avoid duplicating ~120 lines; the logic is
    -- identical and already verified.
    CALL SP_DETECT_BASE();     -- file 04 logic (create this from 04)
    CALL SP_DETECT_NEW();      -- file 17 logic (create this from 17)
    -- Consume streams so SYSTEM$STREAM_HAS_DATA resets to FALSE
    CREATE OR REPLACE TEMPORARY TABLE _drain AS
        SELECT 1 AS X FROM STRM_CUSTOMERS 
        UNION ALL SELECT 1 AS X FROM STRM_ORDERS
        UNION ALL SELECT 1 AS X FROM STRM_PRODUCTS 
        UNION ALL SELECT 1 AS X FROM STRM_PAYMENTS
        UNION ALL SELECT 1 AS X FROM STRM_INVENTORY;
    RETURN 'detect complete';
END;
$$;

-- 2) SCORE procedure = volume-aware scoring for 5 tables (file 05c logic).
CREATE OR REPLACE PROCEDURE SP_SCORE_ALL()
RETURNS STRING LANGUAGE SQL AS
$$ BEGIN CALL SP_SCORE_5TABLES(); RETURN 'score complete'; END; $$;

-- 3) ANALYZE procedure = Cortex diagnosis + impact + exec summary (07-09).
CREATE OR REPLACE PROCEDURE SP_ANALYZE_ALL()
RETURNS STRING LANGUAGE SQL AS
$$ BEGIN CALL SP_DIAGNOSE(); CALL SP_IMPACT(); CALL SP_EXEC_SUMMARY();
        RETURN 'analyze complete'; END; $$;

-- 4) GOVERN procedure = log the automated run.
CREATE OR REPLACE PROCEDURE SP_GOVERN_RUN()
RETURNS STRING LANGUAGE SQL AS
$$
BEGIN
    CALL LOG_EVENT('ORCHESTRATOR','AUTO_PIPELINE_RUN',NULL,NULL,
        'Automated detect->score->analyze completed', 'SYSTEM');
    RETURN 'govern complete';
END;
$$;

-- =====================================================================
-- THE TASK GRAPH (DAG)
-- =====================================================================

-- Root task: ingest, then the graph proceeds. Runs on a schedule but
-- only does work when a stream has data (cheap no-op otherwise).
CREATE OR REPLACE TASK TSK_00_INGEST
    WAREHOUSE = GUARDIANAI_WH
    SCHEDULE  = '1 minute'
    WHEN SYSTEM$STREAM_HAS_DATA('STRM_CUSTOMERS')
      OR SYSTEM$STREAM_HAS_DATA('STRM_ORDERS')
      OR SYSTEM$STREAM_HAS_DATA('STRM_PRODUCTS')
      OR SYSTEM$STREAM_HAS_DATA('STRM_PAYMENTS')
      OR SYSTEM$STREAM_HAS_DATA('STRM_INVENTORY')
AS CALL SP_INGEST_LANDING();

-- If you rely on Snowpipe for ingest, make DETECT the root instead and
-- gate it on the streams. Here we chain after ingest.
CREATE OR REPLACE TASK TSK_01_DETECT
    WAREHOUSE = GUARDIANAI_WH
    AFTER TSK_00_INGEST
AS CALL SP_DETECT_ALL();

CREATE OR REPLACE TASK TSK_02_SCORE
    WAREHOUSE = GUARDIANAI_WH
    AFTER TSK_01_DETECT
AS CALL SP_SCORE_ALL();

CREATE OR REPLACE TASK TSK_03_ANALYZE
    WAREHOUSE = GUARDIANAI_WH
    AFTER TSK_02_SCORE
AS CALL SP_ANALYZE_ALL();

CREATE OR REPLACE TASK TSK_04_GOVERN
    WAREHOUSE = GUARDIANAI_WH
    AFTER TSK_03_ANALYZE
AS CALL SP_GOVERN_RUN();

-- Resume the whole graph (tasks are created SUSPENDED). Resume children
-- first, then the root last.
ALTER TASK TSK_04_GOVERN  RESUME;
ALTER TASK TSK_03_ANALYZE RESUME;
ALTER TASK TSK_02_SCORE   RESUME;
ALTER TASK TSK_01_DETECT  RESUME;
ALTER TASK TSK_00_INGEST  RESUME;

SELECT 'Detection DAG created + resumed (TSK_00_INGEST -> ... -> TSK_04_GOVERN)' AS status;
