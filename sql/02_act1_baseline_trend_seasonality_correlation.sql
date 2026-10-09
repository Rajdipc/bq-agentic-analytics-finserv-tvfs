-- ============================================================================
-- Script: 02_act1_baseline_trend_seasonality_correlation.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql
-- Purpose: Act 1 of the FinServ Risk Investigation — Establish Long-Term
--          Baseline, Cyclical Seasonality, and Operational Metric Correlations
--          using BigQuery Augmented Analytics TVFs:
--            1A. ML.TREND
--            1B. ML.SEASONALITY
--            1C. ML.CORRELATION
--
-- How to run:
--   Paste into BigQuery Studio SQL Editor in the Google Cloud Console and
--   click "Run" (or select individual queries and click "Run selected").
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1A: Isolate Long-Term Dispute Growth from Noise (`ML.TREND`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "Are Reg E electronic payment and banking disputes growing structurally
--    over the multi-year horizon, or are we reacting to short-term noise?"
--
-- Technical Highlight:
--   `ML.TREND` extracts the smoothed long-term trajectory (`trend`) without
--   requiring a `CREATE MODEL` step. Setting `adjust_step_changes => TRUE`
--   blends abrupt regime shifts so we can inspect the underlying secular slope.
-- ----------------------------------------------------------------------------
WITH daily_reg_e AS (
  SELECT
    intake_dt,
    SUM(reg_e_dispute_vol) AS total_reg_e_disputes
  FROM finserv_risk_ops.agg_daily_risk_kpis
  GROUP BY intake_dt
)
SELECT
  intake_dt,
  total_reg_e_disputes,
  ROUND(trend, 2) AS smoothed_long_term_trend,
  time_series_type,
  status
FROM ML.TREND(
  TABLE daily_reg_e,
  data_col => 'total_reg_e_disputes',
  timestamp_col => 'intake_dt',
  smoothing_window_size => 14,
  adjust_step_changes => TRUE
)
ORDER BY intake_dt;


-- ----------------------------------------------------------------------------
-- Query 1B: Decompose Recurring Payment Dispute Cycles (`ML.SEASONALITY`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "What are the predictable weekly, monthly, and yearly seasonal patterns
--    in our consumer dispute intake volume so we can staff risk analysts
--    appropriately and avoid false-positive anomaly alerts?"
--
-- Technical Highlight:
--   `ML.SEASONALITY` decomposes historical time series into `yearly`,
--   `quarterly`, `monthly`, `weekly`, and `daily` components in a single TVF.
-- ----------------------------------------------------------------------------
WITH daily_reg_e AS (
  SELECT
    intake_dt,
    SUM(reg_e_dispute_vol) AS total_reg_e_disputes
  FROM finserv_risk_ops.agg_daily_risk_kpis
  GROUP BY intake_dt
)
SELECT
  intake_dt,
  total_reg_e_disputes,
  ROUND(yearly, 2) AS yearly_seasonality_effect,
  ROUND(monthly, 2) AS monthly_seasonality_effect,
  ROUND(weekly, 2) AS weekly_seasonality_effect,
  status
FROM ML.SEASONALITY(
  TABLE daily_reg_e,
  data_col => 'total_reg_e_disputes',
  timestamp_col => 'intake_dt',
  seasonalities => ['Yearly', 'Monthly', 'Weekly']
)
ORDER BY intake_dt;


-- ----------------------------------------------------------------------------
-- Query 1C: Evaluate Operational Metric Relationships (`ML.CORRELATION`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "Across our banking product lines, which operational metrics have the
--    strongest correlation with total operational handling cost and Tier-2
--    customer escalations?"
--
-- Technical Highlight:
--   `ML.CORRELATION` computes Pearson/Spearman correlation matrices across
--   multiple numerical columns (`target_correlation_cols`) sliced by
--   `dimension_cols`, automatically outputting both per-product segments and
--   the global aggregate row (`ARRAY_LENGTH(segment) = 0`).
-- ----------------------------------------------------------------------------
SELECT
  CASE
    WHEN prod_line_cd IS NULL
      AND NOT EXISTS (SELECT 1 FROM UNNEST(segment) s WHERE s.dimension_col = 'prod_line_cd')
      THEN 'ALL PRODUCT LINES (Global Aggregate)'
    WHEN prod_line_cd IS NULL
      THEN 'UNSPECIFIED PRODUCT'
    ELSE prod_line_cd
  END AS product_line_scope,
  target_col,
  corr_col AS correlated_operational_metric,
  ROUND(correlation, 4) AS pearson_correlation,
  segment_size AS days_observed,
  ROUND(segment_proportion * 100, 2) AS pct_of_total_observations
FROM ML.CORRELATION(
  TABLE finserv_risk_ops.agg_daily_risk_kpis,
  target_col => 'total_ops_cost_usd',
  target_correlation_cols => [
    'reg_e_dispute_vol',
    'avg_intake_fwd_lag_days',
    'tier2_escalation_rate_pct',
    'monetary_relief_rate_pct',
    'sla_breach_rate_pct'
  ],
  dimension_cols => ['prod_line_cd'],
  method => 'PEARSON'
)
WHERE segment_size >= 100
  AND NOT IS_NAN(correlation)
ORDER BY
  ARRAY_LENGTH(segment) ASC,
  ABS(correlation) DESC;
