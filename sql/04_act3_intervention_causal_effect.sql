-- ============================================================================
-- Script: 04_act3_intervention_causal_effect.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql
-- Purpose: Act 3 of the FinServ Risk Investigation — Quantify Counterfactual
--          Causal Impact using `AI.CAUSAL_EFFECT`:
--            3A. Executive Summary View (`output_time_series => FALSE`)
--            3B. Pointwise Counterfactual Time Series (`output_time_series => TRUE`)
--            3C. Multi-Series Product-Level Causal Effect (`id_cols => ['prod_line_cd']`)
--
-- How to run:
--   Paste into BigQuery Studio SQL Editor in the Google Cloud Console and
--   click "Run". For Query 3B, switch the Results pane from "Table" to "Chart"
--   to visualize actual vs. counterfactual predicted dispute volume!
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 3A: Executive Causal Lift Summary (`output_time_series => FALSE`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "Following the emergency P2P & Web fraud-control rollout on July 1, 2020
--    (deployed in response to the May 26 surge), how many Reg E disputes were
--    prevented relative to the synthetic pre-intervention counterfactual, and
--    is the causal effect statistically significant?"
-- ----------------------------------------------------------------------------
WITH daily_reg_e_window AS (
  SELECT
    TIMESTAMP(intake_dt) AS intake_ts,
    SUM(reg_e_dispute_vol) AS total_reg_e_disputes
  FROM finserv_risk_ops.agg_daily_risk_kpis
  -- 6-month pre-intervention training baseline + 3-month post-intervention evaluation
  WHERE intake_dt BETWEEN '2020-01-01' AND '2020-10-01'
  GROUP BY intake_ts
)
SELECT
  ROUND(absolute_effect, 0) AS cumulative_incremental_disputes,
  ROUND(relative_effect * 100, 2) AS relative_effect_pct,
  ROUND(prob_causal_effect * 100, 2) AS causal_confidence_pct,
  ROUND(p_value, 6) AS p_value,
  status
FROM AI.CAUSAL_EFFECT(
  (SELECT * FROM daily_reg_e_window),
  data_col => 'total_reg_e_disputes',
  timestamp_col => 'intake_ts',
  intervention_timestamp => '2020-07-01 00:00:00',
  confidence_level => 0.95,
  output_time_series => FALSE
);


-- ----------------------------------------------------------------------------
-- Query 3B: Pointwise Counterfactual Time Series (`output_time_series => TRUE`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "Plot the day-by-day observed Reg E dispute volume against the predicted
--    counterfactual baseline and 95% confidence bounds."
--
-- Tip for BigQuery Studio Console:
--   After running Query 3B, click the "Chart" tab in the Query Results panel:
--     - Chart type: Line chart
--     - Dimension (X-axis): dispute_date
--     - Measures (Y-axis): total_reg_e_disputes, predicted_counterfactual_disputes,
--                          counterfactual_lower_95, counterfactual_upper_95
--   Note: We order by `is_post_intervention DESC, dispute_date ASC` so the
--   post-intervention counterfactual predictions appear at the top of the table.
-- ----------------------------------------------------------------------------
WITH daily_reg_e_window AS (
  SELECT
    TIMESTAMP(intake_dt) AS intake_ts,
    SUM(reg_e_dispute_vol) AS total_reg_e_disputes
  FROM finserv_risk_ops.agg_daily_risk_kpis
  WHERE intake_dt BETWEEN '2020-01-01' AND '2020-10-01'
  GROUP BY intake_ts
)
SELECT
  DATE(intake_ts) AS dispute_date,
  is_post_intervention,
  total_reg_e_disputes,
  ROUND(predicted_total_reg_e_disputes, 1) AS predicted_counterfactual_disputes,
  ROUND(lower_bound, 1) AS counterfactual_lower_95,
  ROUND(upper_bound, 1) AS counterfactual_upper_95,
  ROUND(total_reg_e_disputes - predicted_total_reg_e_disputes, 1) AS daily_incremental_effect,
  ROUND(prob_causal_effect * 100, 2) AS overall_causal_confidence_pct
FROM AI.CAUSAL_EFFECT(
  (SELECT * FROM daily_reg_e_window),
  data_col => 'total_reg_e_disputes',
  timestamp_col => 'intake_ts',
  intervention_timestamp => '2020-07-01 00:00:00',
  confidence_level => 0.95,
  output_time_series => TRUE
)
ORDER BY is_post_intervention DESC, dispute_date ASC;


-- ----------------------------------------------------------------------------
-- Query 3C: Parallel Multi-Series Causal Effect by Banking Product Line
--           (`id_cols => ['prod_line_cd']`)
-- ----------------------------------------------------------------------------
-- Business Question:
--   "Which banking product lines experienced a statistically significant
--    post-intervention shift in operational dispute handling cost, and what
--    was the dollar impact per product line?"
-- ----------------------------------------------------------------------------
WITH product_daily_cost AS (
  SELECT
    TIMESTAMP(intake_dt) AS intake_ts,
    prod_line_cd,
    SUM(total_ops_cost_usd) AS daily_ops_cost_usd
  FROM finserv_risk_ops.agg_daily_risk_kpis
  WHERE intake_dt BETWEEN '2020-01-01' AND '2020-10-01'
  GROUP BY intake_ts, prod_line_cd
)
SELECT
  prod_line_cd,
  ROUND(absolute_effect, 2) AS cumulative_incremental_cost_usd,
  ROUND(relative_effect * 100, 2) AS relative_cost_change_pct,
  ROUND(prob_causal_effect * 100, 2) AS causal_confidence_pct,
  ROUND(p_value, 4) AS p_value,
  status
FROM AI.CAUSAL_EFFECT(
  (SELECT * FROM product_daily_cost),
  data_col => 'daily_ops_cost_usd',
  timestamp_col => 'intake_ts',
  intervention_timestamp => '2020-07-01 00:00:00',
  id_cols => ['prod_line_cd'],
  confidence_level => 0.95,
  output_time_series => FALSE
)
WHERE status = ''
ORDER BY ABS(absolute_effect) DESC;
