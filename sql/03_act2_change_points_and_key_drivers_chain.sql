-- ============================================================================
-- Script: 03_act2_change_points_and_key_drivers_chain.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql
-- Purpose: Act 2 of the FinServ Risk Investigation — Detect Structural Regime
--          Shifts and Chain the Breakpoint into Multi-Dimensional Attribution:
--            2A. ML.DETECT_CHANGE_POINTS
--            2B. AI.KEY_DRIVERS (Chained from Change Point Detection)
--
-- How to run:
--   Paste into BigQuery Studio SQL Editor in the Google Cloud Console and
--   click "Run".
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 2A: Pinpoint Structural Regime Shifts (`ML.DETECT_CHANGE_POINTS`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "When did our daily Reg E consumer dispute volume experience persistent,
--    statistically significant structural shifts (as opposed to isolated
--    1-day spikes)?"
--
-- Technical Highlight:
--   `ML.DETECT_CHANGE_POINTS` returns contiguous regime intervals
--   `[begin_timestamp, end_timestamp]` along with summary statistics inside
--   the `metrics` STRUCT (`avg`, `min`, `max`, `stddev`, `count`).
-- ----------------------------------------------------------------------------
WITH daily_reg_e AS (
  SELECT
    TIMESTAMP(intake_dt) AS intake_ts,
    SUM(reg_e_dispute_vol) AS total_reg_e_disputes
  FROM finserv_risk_ops.agg_daily_risk_kpis
  GROUP BY intake_ts
)
SELECT
  DATE(begin_timestamp) AS regime_start_date,
  DATE(end_timestamp) AS regime_end_date,
  ROUND(metrics.avg, 1) AS avg_daily_reg_e_disputes,
  ROUND(metrics.min, 1) AS min_daily_reg_e_disputes,
  ROUND(metrics.max, 1) AS max_daily_reg_e_disputes,
  ROUND(metrics.stddev, 1) AS stddev_daily_reg_e_disputes,
  metrics.count AS regime_duration_days,
  status
FROM ML.DETECT_CHANGE_POINTS(
  TABLE daily_reg_e,
  data_col => 'total_reg_e_disputes',
  timestamp_col => 'intake_ts'
)
ORDER BY regime_start_date;


-- ----------------------------------------------------------------------------
-- Query 2B: Multi-Dimensional Root-Cause Attribution (`AI.KEY_DRIVERS`)
--           Dynamically Chained from `ML.DETECT_CHANGE_POINTS`
-- ----------------------------------------------------------------------------
-- Business Question:
--   "Taking the structural surge breakpoint identified by ML.DETECT_CHANGE_POINTS,
--    which specific combinations of Product Line, Sub-Product, Dispute Reason,
--    Submission Channel, and State disproportionately drove the surge?"
--
-- Technical Highlight:
--   We chain `ML.DETECT_CHANGE_POINTS` directly into `AI.KEY_DRIVERS`:
--   1. `detected_regimes` runs `ML.DETECT_CHANGE_POINTS` on daily Reg E volume.
--   2. `primary_surge_regime` selects the detected regime with the highest
--      average daily volume (`ORDER BY regime_avg DESC LIMIT 1`) and keeps
--      BOTH its start and end dates.
--   3. `dispute_comparison_window` labels every dispute INSIDE that regime
--      `[regime_start, regime_end]` as the Interest Group (`is_surge = TRUE`)
--      and an EQUAL-LENGTH window immediately before it as the Reference Group
--      (`is_surge = FALSE`). Equal lengths keep `difference` / `relative_difference`
--      directly interpretable as "extra disputes during the surge".
--      (Comparing a fixed +/-60-day window instead would dilute a short
--      2-week surge with ~45 normal days and hide it.)
--   4. `AI.KEY_DRIVERS` scans multi-dimensional combinations and prunes
--      redundant parent slices (`enable_pruning => TRUE`) to surface the top
--      root-cause segments.
-- ----------------------------------------------------------------------------
WITH daily_reg_e AS (
  SELECT
    TIMESTAMP(intake_dt) AS intake_ts,
    SUM(reg_e_dispute_vol) AS total_reg_e_disputes
  FROM finserv_risk_ops.agg_daily_risk_kpis
  GROUP BY intake_ts
),
detected_regimes AS (
  SELECT
    DATE(begin_timestamp) AS regime_start,
    DATE(end_timestamp) AS regime_end,
    metrics.avg AS regime_avg
  FROM ML.DETECT_CHANGE_POINTS(
    TABLE daily_reg_e,
    data_col => 'total_reg_e_disputes',
    timestamp_col => 'intake_ts'
  )
  WHERE begin_timestamp IS NOT NULL
),
primary_surge_regime AS (
  SELECT
    regime_start,
    regime_end,
    DATE_DIFF(regime_end, regime_start, DAY) + 1 AS regime_days
  FROM detected_regimes
  ORDER BY regime_avg DESC
  LIMIT 1
),
dispute_comparison_window AS (
  SELECT
    f.prod_line_cd,
    f.sub_prod_cd,
    f.iss_cat_cd,
    f.subm_chnl_cd,
    f.jur_state_cd,
    1 AS dispute_count,
    f.intake_dt >= r.regime_start AS is_surge
  FROM finserv_risk_ops.fct_consumer_disputes AS f
  CROSS JOIN primary_surge_regime AS r
  WHERE f.reg_e_elig_flg = 1
    AND f.intake_dt BETWEEN DATE_SUB(r.regime_start, INTERVAL r.regime_days DAY)
                        AND r.regime_end
)
SELECT
  drivers AS contributing_segment_drivers,
  metric_interest AS surge_window_disputes,
  metric_reference AS baseline_window_disputes,
  difference AS net_dispute_change,
  ROUND(relative_difference * 100, 1) AS pct_growth,
  ROUND(unexpected_difference, 1) AS unexpected_excess_disputes,
  ROUND(contribution, 1) AS absolute_contribution,
  ROUND(apriori_support * 100, 2) AS population_support_pct
FROM AI.KEY_DRIVERS(
  (SELECT * FROM dispute_comparison_window),
  metric_col => 'dispute_count',
  interest_label_col => 'is_surge',
  dimension_cols => [
    'prod_line_cd',
    'sub_prod_cd',
    'iss_cat_cd',
    'subm_chnl_cd',
    'jur_state_cd'
  ],
  top_k => 15,
  enable_pruning => TRUE
)
ORDER BY unexpected_difference DESC;
