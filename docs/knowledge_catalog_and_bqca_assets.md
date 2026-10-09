# Knowledge Catalog & BQCA Copy-Paste Assets

This file contains all copy-paste configuration blocks required when setting up **Knowledge Catalog** (Dataplex Business Glossary) and your **BigQuery Conversational Analytics (BQCA) Data Agent** in the Google Cloud Console, as described in the [main deployment runbook (`README.md`)](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/README.md) and the SQL scripts under [`sql/`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/tree/main/sql).

---

## 1. Knowledge Catalog Business Glossary Terms (`FinServ_Risk_Glossary`)

Create these terms in **Dataplex / Knowledge Catalog > Glossaries** (or inside the Data Agent Glossary editor) so the agent can resolve regulated banking vocabulary to your physical BigQuery columns:

| Glossary Term | Synonyms (comma-separated) | Authoritative Business Definition (Copy-Paste) | Linked BigQuery Columns |
| :--- | :--- | :--- | :--- |
| **Reg E Qualifying Dispute** | `Reg E dispute`, `Regulation E claim`, `electronic fund transfer dispute`, `unauthorized EFT` | A consumer dispute governed by the Electronic Fund Transfer Act (Regulation E) involving unauthorized electronic fund transfers, mobile wallet transactions, P2P money transfers, debit/prepaid cards, or digital account fraud. Identified in `fct_consumer_disputes` where `reg_e_elig_flg = 1`, and aggregated daily in `agg_daily_risk_kpis.reg_e_dispute_vol`. | `fct_consumer_disputes.reg_e_elig_flg`, `agg_daily_risk_kpis.reg_e_dispute_vol` |
| **Tier-2 Customer Escalation** | `Tier-2 escalation`, `supervisory review`, `escalated dispute`, `disputed resolution` | A consumer dispute that required escalation beyond Tier-1 automated/frontline intake to Tier-2 supervisory compliance review due to consumer rejection of initial findings, untimely response SLA breach, or high-severity fraud allegation. Identified where `cust_esc_tier2_flg = 1` and tracked as a daily percentage in `agg_daily_risk_kpis.tier2_escalation_rate_pct`. | `fct_consumer_disputes.cust_esc_tier2_flg`, `agg_daily_risk_kpis.tier2_escalation_rate_pct` |
| **Monetary Relief Ratio** | `monetary relief rate`, `cash redress rate`, `upheld with financial relief`, `reimbursement rate` | The percentage of consumer disputes closed with direct monetary reimbursement or fee reversal (`res_disp_cd = 'Closed with monetary relief'`). Tracked at the case level via `mon_rel_ind = 1` and as a daily percentage in `agg_daily_risk_kpis.monetary_relief_rate_pct`. | `fct_consumer_disputes.mon_rel_ind`, `agg_daily_risk_kpis.monetary_relief_rate_pct` |
| **Intake-to-Network Routing Lag** | `routing lag`, `forwarding lag`, `intake latency`, `queue routing delay` | The number of calendar days elapsed between initial dispute intake (`intake_dt`) and forwarding to the bank's operational resolution queue (`network_fwd_dt`). Tracked at the case level in `intake_fwd_lag_days` and averaged daily in `agg_daily_risk_kpis.avg_intake_fwd_lag_days`. | `fct_consumer_disputes.intake_fwd_lag_days`, `agg_daily_risk_kpis.avg_intake_fwd_lag_days` |
| **Regulatory SLA Breach** | `SLA breach`, `untimely response`, `late compliance response` | Failure to provide a formal resolution within the mandated regulatory response window (`timely_response = FALSE`). Identified where `sla_breach_flg = 1` and tracked as a daily percentage in `agg_daily_risk_kpis.sla_breach_rate_pct`. | `fct_consumer_disputes.sla_breach_flg`, `agg_daily_risk_kpis.sla_breach_rate_pct` |
| **Dispute Operational Cost** | `handling cost`, `ops cost`, `dispute servicing cost`, `cost per dispute` | Total estimated operational servicing and settlement processing cost in USD for handling consumer disputes, combining base intake cost ($45), Reg E compliance surcharge ($35), routing lag penalty ($8.50/day), Tier-2 review ($120), and monetary relief processing ($165). | `fct_consumer_disputes.est_ops_cost_usd`, `agg_daily_risk_kpis.total_ops_cost_usd` |

---

## 2. BQCA Data Agent Configuration (`FinServ_Payments_Risk_Agent`)

### 2.1 Agent Name & Description
* **Agent Name:** `FinServ_Payments_Risk_Agent`
* **Agent Description:**
  ```text
  Enterprise Risk & Compliance Data Agent for Consumer Banking and Payments Operations. Answers executive and analyst questions about Regulation E (Reg E) disputes, Tier-2 escalations, routing lag, monetary relief rates, and operational handling costs using BigQuery Augmented Analytics TVFs (ML.TREND, ML.SEASONALITY, ML.CORRELATION, ML.DETECT_CHANGE_POINTS, AI.KEY_DRIVERS, and AI.CAUSAL_EFFECT).
  ```

### 2.2 Agent Instructions (Copy-Paste into the "Instructions" Box)
```text
You are the Consumer Banking & Payments Risk Operations Data Agent. Follow these rules when interpreting questions and generating BigQuery SQL:

1. Knowledge Source Selection:
   - Use `finserv_risk_ops.agg_daily_risk_kpis` for daily time-series analyses (`ML.TREND`, `ML.SEASONALITY`, `ML.DETECT_CHANGE_POINTS`, `AI.CAUSAL_EFFECT`) and metric correlations (`ML.CORRELATION`).
   - Use `finserv_risk_ops.fct_consumer_disputes` for multi-dimensional root-cause attribution (`AI.KEY_DRIVERS`) across granular dimensions (`prod_line_cd`, `sub_prod_cd`, `iss_cat_cd`, `subm_chnl_cd`, `jur_state_cd`, `vuln_cohort_tag`).

2. Default Timeline & Metric Mappings:
   - Always use `intake_dt` as the primary date/timestamp column for time-series questions.
   - When asked about "Reg E disputes" or "electronic payment disputes", use `reg_e_dispute_vol` in `agg_daily_risk_kpis` or filter `reg_e_elig_flg = 1` in `fct_consumer_disputes`.
   - When asked about "Tier-2 escalations", use `tier2_escalation_rate_pct` (in `agg_daily_risk_kpis`) or `cust_esc_tier2_flg` (in `fct_consumer_disputes`).
   - When asked about "routing lag" or "forwarding delay", use `avg_intake_fwd_lag_days` or `intake_fwd_lag_days`.
   - When asked about "operational cost" or "handling cost", use `total_ops_cost_usd` or `est_ops_cost_usd`.

3. Augmented Analytics TVF Selection Rules:
   - For long-term trajectory or secular growth questions, invoke `ML.TREND`.
   - For recurring weekly, monthly, or yearly cyclical pattern questions, invoke `ML.SEASONALITY`.
   - For metric relationship strength or correlation matrix questions, invoke `ML.CORRELATION`.
   - For structural shifts, regime breaks, or baseline changes over time, invoke `ML.DETECT_CHANGE_POINTS`.
   - For root-cause attribution ("what drove the surge/change between two periods"), invoke `AI.KEY_DRIVERS` with `enable_pruning => TRUE`.
   - For quantifying counterfactual impact or intervention ROI after a specific date, invoke `AI.CAUSAL_EFFECT`.
```

---

## 3. Verified Queries (Copy-Paste into the "Verified Queries" Section)

### Verified Query 1: Chained Structural Change Point & Key Drivers Attribution (from [`sql/03_act2_change_points_and_key_drivers_chain.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql))
* **Question:**
  ```text
  Detect when the biggest structural shift occurred in daily Reg E disputes, and identify the top key drivers across product line, sub-product, issue category, submission channel, and state.
  ```
* **SQL Query:**
  ```sql
  WITH daily_reg_e AS (
    SELECT
      TIMESTAMP(intake_dt) AS intake_ts,
      SUM(reg_e_dispute_vol) AS total_reg_e_disputes
    FROM finserv_risk_ops.agg_daily_risk_kpis
    GROUP BY intake_ts
  ),
  detected_regimes AS (
    SELECT
      DATE(begin_timestamp) AS shift_date,
      metrics.avg AS regime_avg,
      metrics.count AS regime_days
    FROM ML.DETECT_CHANGE_POINTS(
      TABLE daily_reg_e,
      data_col => 'total_reg_e_disputes',
      timestamp_col => 'intake_ts'
    )
    WHERE begin_timestamp IS NOT NULL
  ),
  primary_surge_breakpoint AS (
    SELECT shift_date
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
      IF(f.intake_dt >= b.shift_date, TRUE, FALSE) AS is_post_shift
    FROM finserv_risk_ops.fct_consumer_disputes AS f
    CROSS JOIN primary_surge_breakpoint AS b
    WHERE f.reg_e_elig_flg = 1
      AND f.intake_dt BETWEEN DATE_SUB(b.shift_date, INTERVAL 60 DAY)
                          AND DATE_ADD(b.shift_date, INTERVAL 60 DAY)
  )
  SELECT
    drivers AS contributing_segment_drivers,
    metric_interest AS post_shift_disputes,
    metric_reference AS pre_shift_disputes,
    difference AS net_dispute_change,
    ROUND(relative_difference * 100, 1) AS pct_growth,
    ROUND(unexpected_difference, 1) AS unexpected_excess_disputes,
    ROUND(contribution, 1) AS absolute_contribution
  FROM AI.KEY_DRIVERS(
    (SELECT * FROM dispute_comparison_window),
    metric_col => 'dispute_count',
    interest_label_col => 'is_post_shift',
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
  ```

### Verified Query 2: Operational Cost Correlation Matrix by Product Line (from [`sql/02_act1_baseline_trend_seasonality_correlation.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql))
* **Question:**
  ```text
  Which operational risk metrics have the strongest correlation with total dispute operational cost across banking product lines?
  ```
* **SQL Query:**
  ```sql
  SELECT
    IFNULL(prod_line_cd, 'ALL PRODUCT LINES (Global)') AS product_line_scope,
    target_col,
    corr_col AS correlated_operational_metric,
    ROUND(correlation, 4) AS pearson_correlation,
    segment_size AS days_observed
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
  ORDER BY ARRAY_LENGTH(segment) ASC, ABS(correlation) DESC;
  ```

### Verified Query 3: Counterfactual Causal Effect Analysis (from [`sql/04_act3_intervention_causal_effect.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql))
* **Question:**
  ```text
  Quantify the causal effect on daily Reg E dispute volume after 2020-07-01 between 2020-01-01 and 2020-10-01.
  ```
* **SQL Query:**
  ```sql
  WITH daily_reg_e_window AS (
    SELECT
      TIMESTAMP(intake_dt) AS intake_ts,
      SUM(reg_e_dispute_vol) AS total_reg_e_disputes
    FROM finserv_risk_ops.agg_daily_risk_kpis
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
  ```
* **Important Compiler Note on `AI.CAUSAL_EFFECT`:**
  * BigQuery requires `intervention_timestamp` in `AI.CAUSAL_EFFECT` to be a compile-time `TIMESTAMP` literal (e.g., `'2020-07-01 00:00:00'`), rather than a runtime `@parameter` expression. Storing this Verified Query with a literal timestamp allows the BQCA Data Agent to use it as a few-shot SQL template and substitute the user's requested date literal at SQL-generation time.

---

## 4. "Before vs. After Grounding" Conversational Prompt Script

### Phase A: The "Before Grounding" Test (Direct Chat on Raw Cryptic Table)
Run this prompt in a **Direct Conversation** pointed only at the un-enriched `finserv_risk_ops.fct_consumer_disputes` table (before running [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) or attaching the Knowledge Catalog Glossary):

> **Prompt:**
> *"What is the long-term trend and yearly seasonality of our daily Reg E qualifying disputes, and which intake channels and sub-products drove the biggest structural shift in Tier-2 escalations?"*

* **Expected "Before Grounding" Failure / Context Gap:**
  * Without Knowledge Catalog glossary terms or column descriptions, the ungrounded session must guess what *"Reg E qualifying dispute"* (`reg_e_elig_flg`), *"Tier-2 escalation"* (`cust_esc_tier2_flg`), and *"intake channel"* (`subm_chnl_cd`) mean—either asking for clarification, filtering on string literals like `issue LIKE '%Reg E%'` (which returns `0` rows!), or writing brittle manual window functions instead of invoking `ML.TREND`, `ML.SEASONALITY`, `ML.DETECT_CHANGE_POINTS`, and `AI.KEY_DRIVERS`.

---

### Phase B: The "After Grounding" 3-Turn Executive Investigation (In `FinServ_Payments_Risk_Agent`)
Once [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) is applied and `FinServ_Payments_Risk_Agent` is grounded with the Knowledge Catalog Business Glossary, Instructions, and Verified Queries, run this 3-turn executive conversation:

* **Turn 1 (Act 1 — Trend, Seasonality & Correlation):**
  > *"Analyze the long-term trend and yearly and weekly seasonality of our daily Reg E disputes. Then tell me which operational metrics have the strongest correlation with total dispute operational cost across banking product lines."*

* **Turn 2 (Act 2 — Structural Change Points & Key Drivers Attribution):**
  > *"Detect when the biggest structural shift occurred in daily Reg E disputes, and identify the top 10 key drivers across product line, sub-product, issue category, submission channel, and state."*

* **Turn 3 (Act 3 — Counterfactual Causal Effect):**
  > *"Quantify the causal effect on daily Reg E dispute volume after 2020-07-01 between 2020-01-01 and 2020-10-01, and also break down the causal impact on daily operational cost by banking product line."*
