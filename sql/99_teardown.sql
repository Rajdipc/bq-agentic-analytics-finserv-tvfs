-- ============================================================================
-- Script: 99_teardown.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/99_teardown.sql
-- Purpose: Remove every BigQuery object created by this blueprint so you stop
--          incurring storage cost after the demo.
--
-- How to run:
--   Paste into BigQuery Studio and click "Run". This permanently deletes the
--   `finserv_risk_ops` dataset and both tables in it.
--
-- Also clean up manually in the Console (not deletable via SQL):
--   * BigQuery -> Agents: delete the `FinServ_Payments_Risk_Agent` (and any
--     ungrounded baseline agent you created).
--   * Dataplex -> Knowledge Catalog -> Business Glossaries: delete the glossary
--     terms you created (if you do not want to keep them).
--   * Dataplex -> Data profiling & quality / Data insights: delete the scans
--     created for `fct_consumer_disputes` and `agg_daily_risk_kpis`.
-- ============================================================================

DROP SCHEMA IF EXISTS finserv_risk_ops CASCADE;
