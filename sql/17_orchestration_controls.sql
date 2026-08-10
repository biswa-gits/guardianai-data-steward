-- =====================================================================
-- GuardianAI | File 17: ORCHESTRATION CONTROLS & MONITORING
-- Handy commands to start, stop, observe, and manually trigger the
-- automated pipeline. Keep this as your "operator console".
-- =====================================================================

USE WAREHOUSE GUARDIANAI_WH;
USE DATABASE  GUARDIANAI_DB;
USE SCHEMA    CORE;

-- ---------------------------------------------------------------------
-- START everything (resume children first, roots last)
-- ---------------------------------------------------------------------
ALTER TASK TSK_04_GOVERN  RESUME;
ALTER TASK TSK_03_ANALYZE RESUME;
ALTER TASK TSK_02b_REBUILD_PLAN RESUME;
ALTER TASK TSK_02_SCORE   RESUME;
ALTER TASK TSK_01_DETECT  RESUME;
ALTER TASK TSK_00_INGEST  RESUME;
ALTER TASK TSK_REMEDIATE_ON_APPROVAL RESUME;

-- ---------------------------------------------------------------------
-- STOP everything (suspend roots first, then children)
-- ---------------------------------------------------------------------
ALTER TASK TSK_00_INGEST  SUSPEND;
ALTER TASK TSK_01_DETECT  SUSPEND;
ALTER TASK TSK_02_SCORE   SUSPEND;
ALTER TASK TSK_02b_REBUILD_PLAN SUSPEND;
ALTER TASK TSK_03_ANALYZE SUSPEND;
ALTER TASK TSK_04_GOVERN  SUSPEND;
ALTER TASK TSK_REMEDIATE_ON_APPROVAL SUSPEND;

-- ---------------------------------------------------------------------
-- MANUAL TRIGGERS (run the pipeline on demand, without waiting)
-- ---------------------------------------------------------------------
EXECUTE TASK TSK_00_INGEST;                 -- kick the whole detection DAG
CALL SP_DETECT_ALL();  CALL SP_SCORE_ALL(); -- or run stages directly
CALL SP_REMEDIATION_CYCLE();                -- apply approved fixes + validate now

-- ---------------------------------------------------------------------
-- MONITORING
-- ---------------------------------------------------------------------

-- Do the streams currently have new data?
SELECT
  SYSTEM$STREAM_HAS_DATA('STRM_CUSTOMERS') AS customers_new,
  SYSTEM$STREAM_HAS_DATA('STRM_ORDERS')    AS orders_new,
  SYSTEM$STREAM_HAS_DATA('STRM_PRODUCTS')  AS products_new,
  SYSTEM$STREAM_HAS_DATA('STRM_PAYMENTS')  AS payments_new,
  SYSTEM$STREAM_HAS_DATA('STRM_INVENTORY') AS inventory_new,
  SYSTEM$STREAM_HAS_DATA('STRM_APPROVALS') AS approvals_pending;

-- Task run history (last 50 runs, newest first)
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
     SCHEDULED_TIME_RANGE_START => DATEADD('hour',-24,CURRENT_TIMESTAMP())))
ORDER BY SCHEDULED_TIME DESC
LIMIT 50;

-- Current task states
SHOW TASKS LIKE 'TSK_%';

-- Snowpipe status (if using pipes)
-- SELECT SYSTEM$PIPE_STATUS('PIPE_CUSTOMERS');

-- Latest scores (what the dashboard shows)
SELECT * FROM DQ_HEALTH_SCORE
ORDER BY CASE WHEN TABLE_NAME='OVERALL' THEN 1 ELSE 0 END, TABLE_NAME;

-- Recent governance events from the orchestrator
SELECT EVENT_TIME, AGENT, ACTION, DETAIL, ACTOR
FROM DQ_GOVERNANCE_LOG
WHERE AGENT='ORCHESTRATOR'
ORDER BY EVENT_TIME DESC
LIMIT 20;
