-- ============================================================================
-- Script: 01_setup_finserv_risk_mart.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql
-- Purpose: Create the Financial Services Risk Operations dataset and tables
--          directly from `bigquery-public-data.cfpb_complaints.complaint_database`.
--
-- How to run:
--   1. Open BigQuery Studio in the Google Cloud Console.
--   2. Paste this script into a new SQL Editor tab and click "Run".
--   3. No project ID edits are required: BigQuery automatically creates
--      `finserv_risk_ops` in your currently active GCP project.
--
-- Note on Location:
--   `bigquery-public-data` resides in the `US` multi-region, so we explicitly
--   create `finserv_risk_ops` in `US`.
-- ============================================================================

-- 1. Create the dataset in your active project (US multi-region)
CREATE SCHEMA IF NOT EXISTS finserv_risk_ops
OPTIONS (
  location = 'US',
  description = 'Financial Services Consumer Banking & Payments Risk Operations Mart for BigQuery Augmented Analytics TVFs, Knowledge Catalog, and BQCA.'
);

-- ============================================================================
-- 2. Create Fact Table: finserv_risk_ops.fct_consumer_disputes
-- ============================================================================
-- INTENTIONAL DESIGN FOR KNOWLEDGE CATALOG DEMO:
-- We intentionally use realistic, cryptic core-banking column names
-- (e.g., `reg_e_elig_flg`, `intake_fwd_lag_days`, `cust_esc_tier2_flg`,
-- `mon_rel_ind`, `subm_chnl_cd`) WITHOUT column descriptions initially.
--
-- This lets you test an "Ungrounded" BigQuery Conversational Analytics (BQCA)
-- prompt first (Step 5 in https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/README.md)
-- to observe the enterprise Context Gap, before enriching the table with
-- Knowledge Catalog Business Glossary terms and column metadata in
-- `sql/05_enrich_metadata_for_knowledge_catalog.sql`.
-- ============================================================================

CREATE OR REPLACE TABLE finserv_risk_ops.fct_consumer_disputes
PARTITION BY DATE_TRUNC(intake_dt, MONTH)
CLUSTER BY prod_line_cd, subm_chnl_cd, jur_state_cd
AS
WITH base_complaints AS (
  SELECT
    CAST(complaint_id AS STRING) AS dispute_case_id,
    date_received AS intake_dt,
    COALESCE(date_sent_to_company, date_received) AS network_fwd_dt,
    COALESCE(product, 'Unspecified Product') AS prod_line_cd,
    COALESCE(subproduct, 'Unspecified Sub-Product') AS sub_prod_cd,
    COALESCE(issue, 'Unspecified Issue') AS iss_cat_cd,
    COALESCE(subissue, 'Unspecified Sub-Issue') AS sub_iss_cd,
    COALESCE(submitted_via, 'Unknown Channel') AS subm_chnl_cd,
    COALESCE(company_name, 'Unknown Institution') AS inst_name,
    COALESCE(state, 'NA') AS jur_state_cd,
    COALESCE(zip_code, '00000') AS jur_zip_cd,
    COALESCE(tags, 'StandardCohort') AS vuln_cohort_tag,
    COALESCE(company_response_to_consumer, 'Pending') AS res_disp_cd,

    -- Regulatory SLA Breach Flag (1 = Untimely response, 0 = Timely)
    IF(timely_response IS FALSE, 1, 0) AS sla_breach_flg,

    -- Tier-2 Specialist Escalation Flag (PROXY)
    -- The public CFPB `consumer_disputed` field stopped being populated after
    -- April 2017 (0% coverage for 2018-2022), so it is NOT used here. Instead we
    -- proxy "needed specialist / supervisory review" as: the institution breached
    -- the timely-response SLA, the response was marked untimely, or the issue is
    -- a fraud / scam / unauthorized-transaction claim (which banks typically route
    -- to a specialist fraud-ops queue).
    IF(
      timely_response IS FALSE
      OR LOWER(COALESCE(company_response_to_consumer, '')) LIKE '%untimely%'
      OR LOWER(COALESCE(issue, '')) LIKE '%fraud%'
      OR LOWER(COALESCE(issue, '')) LIKE '%scam%'
      OR LOWER(COALESCE(issue, '')) LIKE '%unauthorized%',
      1,
      0
    ) AS cust_esc_tier2_flg,

    -- Monetary Relief Indicator (1 = Closed with monetary relief, 0 = Non-monetary/Other)
    IF(
      LOWER(COALESCE(company_response_to_consumer, '')) = 'closed with monetary relief',
      1,
      0
    ) AS mon_rel_ind,

    -- Regulation E (12 CFR 1005, Electronic Fund Transfers) Scope Flag
    -- Strictly scoped to consumer EFT-capable asset accounts and EFT services:
    --   * Checking / savings / other deposit services (CDs excluded: time deposits
    --     are rarely EFT-accessed)
    --   * Prepaid accounts covered by the Reg E Prepaid Rule (general-purpose,
    --     government benefit, payroll, student prepaid). Gift cards are excluded
    --     (separate Reg E gift-card provisions, no error-resolution rights).
    --   * Mobile / digital wallets and domestic & international (remittance)
    --     money transfers.
    -- Deliberately EXCLUDED:
    --   * Credit cards (general-purpose and store) - governed by Regulation Z
    --     (TILA / Fair Credit Billing Act), NOT Regulation E.
    --   * Virtual currency, money orders, traveler's checks, check cashing,
    --     currency exchange, refund anticipation checks, debt settlement.
    --   * FCRA credit-reporting complaints (Regulation V).
    IF(
      (
        LOWER(COALESCE(product, '')) IN ('checking or savings account', 'bank account or service')
        AND LOWER(COALESCE(subproduct, '')) NOT LIKE 'cd (certificate of deposit)%'
      )
      OR LOWER(COALESCE(product, '')) = 'prepaid card'
      OR (
        LOWER(COALESCE(product, '')) = 'credit card or prepaid card'
        AND LOWER(COALESCE(subproduct, '')) IN (
          'general-purpose prepaid card',
          'government benefit card',
          'payroll card',
          'student prepaid card'
        )
      )
      OR (
        LOWER(COALESCE(product, '')) = 'money transfer, virtual currency, or money service'
        AND LOWER(COALESCE(subproduct, '')) IN (
          'mobile or digital wallet',
          'domestic (us) money transfer',
          'international money transfer'
        )
      ),
      1,
      0
    ) AS reg_e_elig_flg,

    -- Intake-to-Network Routing Lag (in calendar days, clamped to [0, 90] to remove data entry outliers)
    LEAST(
      90,
      GREATEST(0, DATE_DIFF(COALESCE(date_sent_to_company, date_received), date_received, DAY))
    ) AS intake_fwd_lag_days

  FROM `bigquery-public-data.cfpb_complaints.complaint_database`
  WHERE date_received BETWEEN '2018-01-01' AND '2022-12-31'
    AND complaint_id IS NOT NULL
)
SELECT
  dispute_case_id,
  intake_dt,
  network_fwd_dt,
  prod_line_cd,
  sub_prod_cd,
  iss_cat_cd,
  sub_iss_cd,
  subm_chnl_cd,
  inst_name,
  jur_state_cd,
  jur_zip_cd,
  vuln_cohort_tag,
  res_disp_cd,
  sla_breach_flg,
  cust_esc_tier2_flg,
  mon_rel_ind,
  reg_e_elig_flg,
  intake_fwd_lag_days,

  -- Deterministic Dispute Operational Handling Cost (USD):
  -- Base intake cost ($45) + Reg E investigation surcharge ($35)
  -- + Routing lag penalty ($8.50/day) + Tier-2 manual escalation review ($120)
  -- + Monetary relief settlement processing ($165)
  ROUND(
    CAST(
      45.0
      + (reg_e_elig_flg * 35.0)
      + (intake_fwd_lag_days * 8.5)
      + (cust_esc_tier2_flg * 120.0)
      + (mon_rel_ind * 165.0)
      AS NUMERIC
    ),
    2
  ) AS est_ops_cost_usd
FROM base_complaints;

-- ============================================================================
-- 3. Create Daily Rollup Table: finserv_risk_ops.agg_daily_risk_kpis
-- ============================================================================
-- Provides continuous daily time-series and multi-metric operational KPIs
-- across product lines for `ML.TREND`, `ML.SEASONALITY`, `ML.CORRELATION`,
-- `ML.DETECT_CHANGE_POINTS`, and `AI.CAUSAL_EFFECT`.
-- ============================================================================

CREATE OR REPLACE TABLE finserv_risk_ops.agg_daily_risk_kpis
PARTITION BY DATE_TRUNC(intake_dt, MONTH)
CLUSTER BY prod_line_cd
AS
SELECT
  intake_dt,
  prod_line_cd,
  COUNT(*) AS daily_dispute_vol,
  SUM(reg_e_elig_flg) AS reg_e_dispute_vol,
  ROUND(AVG(intake_fwd_lag_days), 2) AS avg_intake_fwd_lag_days,
  ROUND(100.0 * SAFE_DIVIDE(SUM(cust_esc_tier2_flg), COUNT(*)), 2) AS tier2_escalation_rate_pct,
  ROUND(100.0 * SAFE_DIVIDE(SUM(mon_rel_ind), COUNT(*)), 2) AS monetary_relief_rate_pct,
  ROUND(100.0 * SAFE_DIVIDE(SUM(sla_breach_flg), COUNT(*)), 2) AS sla_breach_rate_pct,
  ROUND(SUM(CAST(est_ops_cost_usd AS FLOAT64)), 2) AS total_ops_cost_usd,
  ROUND(AVG(CAST(est_ops_cost_usd AS FLOAT64)), 2) AS avg_ops_cost_per_dispute_usd
FROM finserv_risk_ops.fct_consumer_disputes
GROUP BY
  intake_dt,
  prod_line_cd;
