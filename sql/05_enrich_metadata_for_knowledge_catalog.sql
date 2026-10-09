-- ============================================================================
-- Script: 05_enrich_metadata_for_knowledge_catalog.sql
-- Repository: https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql
-- Purpose: Enrich `finserv_risk_ops.fct_consumer_disputes` and
--          `finserv_risk_ops.agg_daily_risk_kpis` with authoritative table
--          and column descriptions so Knowledge Catalog and BigQuery
--          Conversational Analytics (BQCA) can bridge cryptic banking schema
--          names to enterprise risk terminology.
--
-- When to run:
--   Run this script in the BigQuery Studio SQL Editor AFTER testing the
--   "Before Grounding" prompt (Step 5 in https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/README.md)
--   and as part of Step 6 (Knowledge Catalog & Metadata Grounding).
-- ============================================================================

-- 1. Enrich Fact Table: finserv_risk_ops.fct_consumer_disputes
ALTER TABLE finserv_risk_ops.fct_consumer_disputes
SET OPTIONS (
  description = 'Case-level Consumer Banking & Payments Risk Operations fact table. Contains regulatory consumer complaints, Reg E electronic fund transfer eligibility flags, intake-to-network routing lag days, Tier-2 customer escalations, monetary relief indicators, and estimated operational handling costs.'
);

ALTER TABLE finserv_risk_ops.fct_consumer_disputes
  ALTER COLUMN dispute_case_id SET OPTIONS (
    description = 'Unique identifier for each registered consumer banking dispute case (sourced from CFPB complaint_id).'
  ),
  ALTER COLUMN intake_dt SET OPTIONS (
    description = 'Calendar date when the consumer dispute was received at intake. Default timeline/date column for all time-series, trend, seasonality, change-point, and causal analyses.'
  ),
  ALTER COLUMN network_fwd_dt SET OPTIONS (
    description = 'Calendar date when the dispute was routed and forwarded to the financial institution risk operations queue.'
  ),
  ALTER COLUMN prod_line_cd SET OPTIONS (
    description = 'Primary banking product line (e.g., Checking or savings account, Money transfer, virtual currency, or money service, Credit card or prepaid card, Mortgage, Debt collection).'
  ),
  ALTER COLUMN sub_prod_cd SET OPTIONS (
    description = 'Granular sub-product category (e.g., Mobile wallet, Domestic US money transfer, Checking account, General-purpose prepaid card).'
  ),
  ALTER COLUMN iss_cat_cd SET OPTIONS (
    description = 'Primary dispute reason category reported by the consumer (e.g., Fraud or scam, Unauthorized transactions or other transaction problem, Managing an account).'
  ),
  ALTER COLUMN sub_iss_cd SET OPTIONS (
    description = 'Secondary detailed dispute reason code.'
  ),
  ALTER COLUMN subm_chnl_cd SET OPTIONS (
    description = 'Intake submission channel used by the consumer (e.g., Web, Referral, Phone, Postal mail, Fax).'
  ),
  ALTER COLUMN inst_name SET OPTIONS (
    description = 'Legal name of the financial institution associated with the dispute.'
  ),
  ALTER COLUMN jur_state_cd SET OPTIONS (
    description = 'Two-letter US state postal code representing the consumer regulatory jurisdiction.'
  ),
  ALTER COLUMN jur_zip_cd SET OPTIONS (
    description = 'Consumer mailing ZIP code.'
  ),
  ALTER COLUMN vuln_cohort_tag SET OPTIONS (
    description = 'Vulnerable consumer cohort classification tag (e.g., Older American, Servicemember, or StandardCohort).'
  ),
  ALTER COLUMN res_disp_cd SET OPTIONS (
    description = 'Final resolution disposition code reported by the institution (e.g., Closed with monetary relief, Closed with non-monetary relief, Closed with explanation).'
  ),
  ALTER COLUMN sla_breach_flg SET OPTIONS (
    description = 'Binary flag (1 = Breach, 0 = Compliant) indicating whether the institution failed to meet the regulatory timely response SLA.'
  ),
  ALTER COLUMN cust_esc_tier2_flg SET OPTIONS (
    description = 'Binary flag (1 = Escalated to Tier-2 supervisory review, 0 = Resolved in Tier-1) triggered by consumer dispute of resolution, untimely response, or fraud/unauthorized transaction claim.'
  ),
  ALTER COLUMN mon_rel_ind SET OPTIONS (
    description = 'Binary indicator (1 = Monetary relief granted, 0 = No monetary relief) when the dispute was closed with direct financial reimbursement to the consumer.'
  ),
  ALTER COLUMN reg_e_elig_flg SET OPTIONS (
    description = 'Binary flag (1 = Reg E Qualifying Dispute, 0 = Non-Reg E) identifying Electronic Fund Transfer Act (Regulation E) and digital payment/unauthorized transaction disputes.'
  ),
  ALTER COLUMN intake_fwd_lag_days SET OPTIONS (
    description = 'Number of calendar days elapsed between initial dispute intake (intake_dt) and forwarding to the bank operations queue (network_fwd_dt). Also referred to as Routing Lag.'
  ),
  ALTER COLUMN est_ops_cost_usd SET OPTIONS (
    description = 'Estimated total operational handling and settlement processing cost in USD for the dispute case.'
  );


-- 2. Enrich Daily Rollup Table: finserv_risk_ops.agg_daily_risk_kpis
ALTER TABLE finserv_risk_ops.agg_daily_risk_kpis
SET OPTIONS (
  description = 'Daily aggregated Consumer Banking & Payments Risk KPI table by intake_dt and prod_line_cd. Preferred knowledge source for time-series TVFs (ML.TREND, ML.SEASONALITY, ML.DETECT_CHANGE_POINTS, AI.CAUSAL_EFFECT) and metric correlation analysis (ML.CORRELATION).'
);

ALTER TABLE finserv_risk_ops.agg_daily_risk_kpis
  ALTER COLUMN intake_dt SET OPTIONS (
    description = 'Calendar date of dispute intake. Use as timestamp_col in ML.TREND, ML.SEASONALITY, ML.DETECT_CHANGE_POINTS, and AI.CAUSAL_EFFECT.'
  ),
  ALTER COLUMN prod_line_cd SET OPTIONS (
    description = 'Primary banking product line. Use as dimension_cols in ML.CORRELATION or id_cols in multi-series TVFs.'
  ),
  ALTER COLUMN daily_dispute_vol SET OPTIONS (
    description = 'Total count of consumer disputes received on intake_dt for the product line.'
  ),
  ALTER COLUMN reg_e_dispute_vol SET OPTIONS (
    description = 'Total count of Regulation E (Reg E) qualifying electronic payment and unauthorized transaction disputes received on intake_dt.'
  ),
  ALTER COLUMN avg_intake_fwd_lag_days SET OPTIONS (
    description = 'Average Intake-to-Network Routing Lag in days for disputes received on intake_dt.'
  ),
  ALTER COLUMN tier2_escalation_rate_pct SET OPTIONS (
    description = 'Percentage (0 to 100) of disputes received on intake_dt that escalated to Tier-2 supervisory review.'
  ),
  ALTER COLUMN monetary_relief_rate_pct SET OPTIONS (
    description = 'Percentage (0 to 100) of disputes received on intake_dt that closed with monetary relief reimbursement.'
  ),
  ALTER COLUMN sla_breach_rate_pct SET OPTIONS (
    description = 'Percentage (0 to 100) of disputes received on intake_dt that breached the regulatory timely response SLA.'
  ),
  ALTER COLUMN total_ops_cost_usd SET OPTIONS (
    description = 'Total estimated operational handling cost in USD across all disputes received on intake_dt for the product line.'
  ),
  ALTER COLUMN avg_ops_cost_per_dispute_usd SET OPTIONS (
    description = 'Average operational handling cost in USD per dispute case on intake_dt.'
  );
