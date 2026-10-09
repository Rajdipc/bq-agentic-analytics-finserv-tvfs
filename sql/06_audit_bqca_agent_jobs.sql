-- ============================================================================
-- Script: 06_audit_bqca_agent_jobs.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/06_audit_bqca_agent_jobs.sql
-- Purpose: Inspect and audit the exact SQL queries (including Augmented
--          Analytics TVF invocations) generated and executed by BigQuery
--          Conversational Analytics (BQCA) Data Agents.
--
-- How it works:
--   BigQuery automatically attaches system labels to every job executed by
--   Conversational Analytics:
--     - `ca-bq-job: true`
--     - `data-agent-id: <DATA_AGENT_ID>`
--     - `conversation-id: <CONVERSATION_ID>`
--
--   Using unqualified `region-us`.INFORMATION_SCHEMA.JOBS automatically
--   queries the active project in BigQuery Studio without hardcoding a
--   GCP Project ID.
-- ============================================================================

SELECT
  creation_time,
  job_id,
  user_email,
  (SELECT value FROM UNNEST(labels) WHERE key = 'data-agent-id') AS data_agent_id,
  (SELECT value FROM UNNEST(labels) WHERE key = 'conversation-id') AS conversation_id,
  REGEXP_EXTRACT_ALL(
    UPPER(query),
    r'(?:AI|ML)\.(?:KEY_DRIVERS|CAUSAL_EFFECT|CORRELATION|DETECT_CHANGE_POINTS|TREND|SEASONALITY|FORECAST|DETECT_ANOMALIES)'
  ) AS invoked_augmented_analytics_tvfs,
  IF(error_result IS NULL, 'SUCCESS', CONCAT('ERROR: ', error_result.reason)) AS job_status,
  ROUND(total_bytes_billed / POW(1024, 2), 2) AS mb_billed,
  TIMESTAMP_DIFF(end_time, start_time, MILLISECOND) AS execution_ms,
  query AS generated_sql
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND EXISTS (
    SELECT 1
    FROM UNNEST(labels) AS label
    WHERE label.key = 'ca-bq-job'
      AND label.value = 'true'
  )
ORDER BY creation_time DESC
LIMIT 50;
