# Grounded Agentic Analytics in BigQuery

[![GitHub Repository](https://img.shields.io/badge/GitHub-bq--agentic--analytics--finserv--tvfs-181717?logo=github)](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-BigQuery%20AI-4285F4?logo=google-cloud)](https://cloud.google.com/bigquery)
[![Augmented Analytics TVFs](https://img.shields.io/badge/GoogleSQL-6%20Augmented%20Analytics%20TVFs-FBBC04?logo=google-cloud)](https://cloud.google.com/blog/products/data-analytics/bigquery-augmented-analytics-tvfs)
[![Knowledge Catalog](https://img.shields.io/badge/Knowledge%20Catalog-Dataplex%20Governance-34A853?logo=google-cloud)](https://docs.cloud.google.com/knowledge-catalog/docs/data-insights)
[![Conversational Analytics](https://img.shields.io/badge/Conversational%20Analytics-BQCA%20Data%20Agents-EA4335?logo=google-cloud)](https://docs.cloud.google.com/bigquery/docs/conversational-analytics)

An end-to-end, 100% GCP-native reference implementation for **Financial Services Consumer Banking & Payments Risk Operations** that combines all six **BigQuery Augmented Analytics Table-Valued Functions (TVFs)** (`ML.TREND`, `ML.SEASONALITY`, `ML.CORRELATION`, `ML.DETECT_CHANGE_POINTS`, `AI.KEY_DRIVERS`, and `AI.CAUSAL_EFFECT`) with **Knowledge Catalog (Dataplex)** semantic governance and **BigQuery Conversational Analytics (BQCA)** Data Agents. Everything runs inside BigQuery via the **Google Cloud Console** (or Cloud Shell) with **zero Terraform, zero Makefiles, zero notebooks, and zero hardcoded GCP project IDs**.

**Contents**
| | |
| :--- | :--- |
| [TL;DR](#tldr) | [Data Model & Cryptic Banking Schema](#data-model--cryptic-banking-schema) |
| [⚠️ Dataset Location (`US` Multi-Region)](#️-dataset-location-us-multi-region) | [Step-by-Step Deployment (Google Cloud Console)](#step-by-step-deployment-google-cloud-console--preferred) |
| [Architecture](#architecture) | [Verifying It Worked](#verifying-it-worked) |
| [Official GCP Documentation Reference](#official-gcp-documentation-reference) | [Troubleshooting & SQL Gotchas](#troubleshooting--sql-gotchas) |
| [Prerequisites](#prerequisites) | [Cost Breakdown & Cleanup](#cost-breakdown--cleanup) |

---

## TL;DR

**Preferred path — Google Cloud Console (no CLI required):**

1. **Build the FinServ Risk Mart ([`sql/01`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql)):** Open **BigQuery Studio**, paste and run [`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql). It automatically creates the `finserv_risk_ops` dataset in the `US` multi-region and transforms `bigquery-public-data.cfpb_complaints.complaint_database` into two tables (`fct_consumer_disputes` and `agg_daily_risk_kpis`) with realistic, intentionally cryptic core-banking column names (`reg_e_elig_flg`, `cust_esc_tier2_flg`, `mon_rel_ind`, `intake_fwd_lag_days`, `subm_chnl_cd`, `est_ops_cost_usd`).
2. **Run the 3-Act Diagnostic SQL Chain ([`sql/02`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql)–[`sql/04`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql)):**
   * **Act 1 ([`sql/02_act1_baseline_trend_seasonality_correlation.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql)):** Extracts smoothed long-term trajectory (`ML.TREND`), decomposes `Yearly`/`Monthly`/`Weekly` cycles (`ML.SEASONALITY`), and computes per-product operational cost correlations (`ML.CORRELATION`).
   * **Act 2 ([`sql/03_act2_change_points_and_key_drivers_chain.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql)):** Detects structural regime shifts (`ML.DETECT_CHANGE_POINTS`) and dynamically chains the discovered `shift_date` into multi-dimensional root-cause attribution (`AI.KEY_DRIVERS`) with zero hardcoded dates.
   * **Act 3 ([`sql/04_act3_intervention_causal_effect.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql)):** Quantifies counterfactual incremental Reg E disputes and per-product operational handling cost impact (`AI.CAUSAL_EFFECT` with `output_time_series => FALSE/TRUE` and `id_cols => ['prod_line_cd']`).
3. **Compare "Before" vs. "After" Knowledge Catalog Grounding ([`sql/05`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) & [`docs/`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/tree/main/docs)):** Test an ungrounded BQCA conversation against the raw cryptic table, then run [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) and apply the 6 Glossary terms (`FinServ_Risk_Glossary`), Agent System Instructions (`FinServ_Payments_Risk_Agent`), and 3 Verified Queries from [`docs/knowledge_catalog_and_bqca_assets.md`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md).
4. **Audit Agent TVF Execution ([`sql/06`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/06_audit_bqca_agent_jobs.sql)):** Run [`sql/06_audit_bqca_agent_jobs.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/06_audit_bqca_agent_jobs.sql) to inspect `region-us.INFORMATION_SCHEMA.JOBS` (filtering on `ca-bq-job = 'true'`) and verify the exact Augmented Analytics TVFs executed by the Data Agent.

<details>
<summary><strong>Alternative path — Run the SQL scripts from Google Cloud Shell in 2 minutes</strong></summary>

```bash
git clone https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs.git
cd bq-agentic-analytics-finserv-tvfs

# Cloud Shell inherits your active project automatically — no project ID is hardcoded anywhere
gcloud services enable \
  bigquery.googleapis.com \
  dataplex.googleapis.com \
  datacatalog.googleapis.com \
  geminidataanalytics.googleapis.com \
  cloudaicompanion.googleapis.com

bq query --location=US --use_legacy_sql=false < sql/01_setup_finserv_risk_mart.sql
bq query --location=US --use_legacy_sql=false < sql/02_act1_baseline_trend_seasonality_correlation.sql
bq query --location=US --use_legacy_sql=false < sql/03_act2_change_points_and_key_drivers_chain.sql
bq query --location=US --use_legacy_sql=false < sql/04_act3_intervention_causal_effect.sql
bq query --location=US --use_legacy_sql=false < sql/05_enrich_metadata_for_knowledge_catalog.sql
```

</details>

> [!IMPORTANT]
> **Two ordering notes before you begin:**
>
> * **`finserv_risk_ops` must reside in the `US` multi-region.** [`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql) automatically specifies `OPTIONS (location = 'US')` because `bigquery-public-data.cfpb_complaints.complaint_database` is hosted in `US`.
> * **Run the "Before Grounding" BQCA test *before* executing [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql).** Once [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) populates column descriptions in BigQuery's catalog, Conversational Analytics immediately reads them into its prompt context.

---

## ⚠️ Dataset Location (`US` Multi-Region)

| Setting | Value to Use | Why |
| :--- | :--- | :--- |
| **BigQuery Dataset Location** | **`US` (Multi-region)** | The source public dataset (`bigquery-public-data.cfpb_complaints.complaint_database`) lives in `US`. Every TVF query in [`sql/`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/tree/main/sql) executes in `US`. |
| **Knowledge Catalog Glossary Location** | **`US` (Multi-region)** or **Global** | Matches the BigQuery dataset location so glossary terms attach cleanly to `finserv_risk_ops` columns. |
| **GCP Project ID** | **Dynamic (Ambient Project)** | None of the SQL scripts hardcode a project ID. Qualifying objects as `finserv_risk_ops.<table_name>` resolves automatically against whichever project is active in the Google Cloud Console or `gcloud config`. |

---

## Architecture

```
+---------------------------------------------------------------------------------------------------+
|                     SOURCE: bigquery-public-data.cfpb_complaints.complaint_database               |
|                                (Public US Consumer Financial Complaints)                          |
+-------------------------------------------------+-------------------------------------------------+
                                                  |
                                                  | sql/01_setup_finserv_risk_mart.sql
                                                  v
+---------------------------------------------------------------------------------------------------+
|                       CURATED FINSERV RISK MART (Dataset: finserv_risk_ops)                       |
|                                                                                                   |
|  1. fct_consumer_disputes (PARTITION BY DATE_TRUNC(intake_dt, MONTH))                             |
|     Cryptic Core-Banking Columns: reg_e_elig_flg | cust_esc_tier2_flg | mon_rel_ind               |
|                                   intake_fwd_lag_days | sla_breach_flg | est_ops_cost_usd         |
|                                                                                                   |
|  2. agg_daily_risk_kpis (Daily KPI rollup by intake_dt, prod_line_cd)                             |
|     Metrics: daily_dispute_vol | reg_e_dispute_vol | avg_intake_fwd_lag_days                      |
|              tier2_escalation_rate_pct | monetary_relief_rate_pct | total_ops_cost_usd            |
+-----------------------+---------------------------------------------------+-----------------------+
                        |                                                   |
                        v                                                   v
+-----------------------------------------------+   +-----------------------------------------------+
|   SEMANTIC GOVERNANCE (Knowledge Catalog)     |   |   IN-WAREHOUSE STATISTICAL ENGINE (6 TVFs)    |
|                                               |   |                                               |
| - sql/05_enrich_metadata_for_knowledge_...sql |   | Act 1: Baseline & Cost Drivers (sql/02_...)   |
| - Authoritative Table & Column Descriptions   |   |   - ML.TREND (adjust_step_changes => TRUE)    |
| - Dataplex Data Profile & Data Insights       |   |   - ML.SEASONALITY (Yearly, Monthly, Weekly)  |
| - Business Glossary (FinServ_Risk_Glossary):  |   |   - ML.CORRELATION (target: total_ops_cost)   |
|   1. Reg E Qualifying Dispute                 |   |                                               |
|   2. Tier-2 Customer Escalation               |   | Act 2: Regime Shift & Drivers (sql/03_...)    |
|   3. Monetary Relief Ratio                    |   |   - ML.DETECT_CHANGE_POINTS                   |
|   4. Intake-to-Network Routing Lag            |   |       └──> Chained via SQL CTE into:          |
|   5. Regulatory SLA Breach                    |   |   - AI.KEY_DRIVERS (enable_pruning => TRUE)   |
|   6. Dispute Operational Cost                 |   |                                               |
|                                               |   | Act 3: Counterfactual Impact (sql/04_...)     |
|                                               |   |   - AI.CAUSAL_EFFECT (id_cols: prod_line_cd)  |
+-----------------------+-----------------------+   +-----------------------+-----------------------+
                        |                                                   |
                        +-------------------------+-------------------------+
                                                  |
                                                  v
+---------------------------------------------------------------------------------------------------+
|          AGENTIC LAYER: BigQuery Conversational Analytics (FinServ_Payments_Risk_Agent)           |
|                                                                                                   |
|  - Grounded on Knowledge Catalog column descriptions + FinServ_Risk_Glossary                      |
|  - Configured with System Instructions + 3 Verified Queries (docs/knowledge_catalog_and_bqca...)  |
|  - Translates natural-language executive risk questions into deterministic TVF SQL                |
|  - Audited via `region-us`.INFORMATION_SCHEMA.JOBS (sql/06_audit_bqca_agent_jobs.sql)             |
+---------------------------------------------------------------------------------------------------+
```

---

## Official GCP Documentation Reference

Every feature demonstrated in this repository maps directly to official Google Cloud documentation:

| Feature / Component | Role in This Blueprint | Official Documentation Link |
| :--- | :--- | :--- |
| **Launch Blog Post** | Overview of the 6 Augmented Analytics TVFs | [Streamline data analysis with BigQuery Augmented Analytics TVFs](https://cloud.google.com/blog/products/data-analytics/bigquery-augmented-analytics-tvfs) |
| **`ML.TREND`** | Act 1 ([`sql/02`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql)): Extracts smoothed secular trajectory (`trend`) with `smoothing_window_size => 14` and `adjust_step_changes => TRUE` | [`ML.TREND` syntax reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-trend) |
| **`ML.SEASONALITY`** | Act 1 ([`sql/02`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql)): Decomposes time series into `yearly`, `monthly`, and `weekly` cyclical components | [`ML.SEASONALITY` syntax reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-seasonality) |
| **`ML.CORRELATION`** | Act 1 ([`sql/02`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql)): Computes Pearson correlations between `total_ops_cost_usd` and operational risk KPIs across `prod_line_cd` | [`ML.CORRELATION` syntax reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-correlation) |
| **`ML.DETECT_CHANGE_POINTS`** | Act 2 ([`sql/03`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql)): Identifies contiguous structural regime intervals (`[begin_timestamp, end_timestamp]`) and `metrics` summary stats | [`ML.DETECT_CHANGE_POINTS` syntax reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-detect-change-points) |
| **`AI.KEY_DRIVERS`** | Act 2 ([`sql/03`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql)): Ranks multi-dimensional segment combinations (`drivers`) by `unexpected_difference` and `contribution` with `enable_pruning => TRUE` | [`AI.KEY_DRIVERS` syntax reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-key-drivers) |
| **`AI.CAUSAL_EFFECT`** | Act 3 ([`sql/04`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql)): Quantifies counterfactual impact (`absolute_effect`, `relative_effect`, `prob_causal_effect`, `p_value`) after `intervention_timestamp` | [`AI.CAUSAL_EFFECT` syntax reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-causal-effect) |
| **BigQuery Conversational Analytics** | Natural-language analytics & native integration with `AI.*` and `ML.*` TVFs | [Conversational Analytics overview](https://cloud.google.com/bigquery/docs/conversational-analytics) |
| **BQCA Data Agents** | Custom agent instructions & golden verified queries (`FinServ_Payments_Risk_Agent`) | [Create and configure Data Agents](https://cloud.google.com/bigquery/docs/data-agents) |
| **Knowledge Catalog Data Insights** | Automated profiling & LLM-generated SQL insights on tables | [Generate Data Insights in Knowledge Catalog](https://cloud.google.com/dataplex/docs/data-insights) |
| **Knowledge Catalog Glossaries** | Business Glossary terms (`FinServ_Risk_Glossary`) linked to physical BigQuery columns | [Manage Business Glossaries in Knowledge Catalog](https://cloud.google.com/dataplex/docs/business-glossary-overview) |

---

## Prerequisites

### 1. Required Google Cloud APIs

Enable these five APIs in **APIs & Services → Library** in the Google Cloud Console, or run this one-liner in Cloud Shell:

```bash
gcloud services enable \
  bigquery.googleapis.com \
  dataplex.googleapis.com \
  datacatalog.googleapis.com \
  geminidataanalytics.googleapis.com \
  cloudaicompanion.googleapis.com
```

### 2. Required IAM Roles

| Role | Purpose |
| :--- | :--- |
| `roles/bigquery.dataEditor` + `roles/bigquery.jobUser` | Create `finserv_risk_ops`, build tables, alter column metadata, and execute TVFs |
| `roles/dataplex.catalogEditor` + `roles/dataplex.dataScanAdmin` | Create Knowledge Catalog Business Glossaries and run Data Profile / Data Insights scans |
| `roles/geminidataanalytics.dataAgentAdmin` (or `roles/bigquery.admin`) | Create and publish BigQuery Conversational Analytics Data Agents |

---

## Repository Structure

```
bq-agentic-analytics-finserv-tvfs/
├── README.md                                              # Console & Cloud Shell deployment runbook
├── sql/
│   ├── 01_setup_finserv_risk_mart.sql                     # DDL: Creates finserv_risk_ops, fct_consumer_disputes & agg_daily_risk_kpis
│   ├── 02_act1_baseline_trend_seasonality_correlation.sql # Act 1: ML.TREND, ML.SEASONALITY, ML.CORRELATION
│   ├── 03_act2_change_points_and_key_drivers_chain.sql    # Act 2: ML.DETECT_CHANGE_POINTS chained into AI.KEY_DRIVERS
│   ├── 04_act3_intervention_causal_effect.sql             # Act 3: Counterfactual AI.CAUSAL_EFFECT (summary, time series & multi-series)
│   ├── 05_enrich_metadata_for_knowledge_catalog.sql       # DDL: Populates authoritative table & column descriptions
│   └── 06_audit_bqca_agent_jobs.sql                       # Audit: Verifies agent TVF calls via `region-us`.INFORMATION_SCHEMA.JOBS
└── docs/
    └── knowledge_catalog_and_bqca_assets.md               # Copy-paste Glossary Terms, Agent Instructions & Verified Queries
```

| File Path | Purpose |
| :--- | :--- |
| [`README.md`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/README.md) | Step-by-step Google Cloud Console and Cloud Shell deployment runbook |
| [`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql) | DDL: Creates `finserv_risk_ops`, `fct_consumer_disputes`, and `agg_daily_risk_kpis` |
| [`sql/02_act1_baseline_trend_seasonality_correlation.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql) | Act 1: `ML.TREND`, `ML.SEASONALITY`, and `ML.CORRELATION` |
| [`sql/03_act2_change_points_and_key_drivers_chain.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql) | Act 2: `ML.DETECT_CHANGE_POINTS` chained dynamically into `AI.KEY_DRIVERS` |
| [`sql/04_act3_intervention_causal_effect.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql) | Act 3: Counterfactual `AI.CAUSAL_EFFECT` (summary, time series, and multi-series `id_cols`) |
| [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) | DDL: Populates authoritative table and column descriptions for Knowledge Catalog & BQCA |
| [`sql/06_audit_bqca_agent_jobs.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/06_audit_bqca_agent_jobs.sql) | Audit: Verifies agent TVF execution via `` `region-us`.INFORMATION_SCHEMA.JOBS `` |
| [`docs/knowledge_catalog_and_bqca_assets.md`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md) | Copy-paste Knowledge Catalog Business Glossary terms, Agent Instructions, and Verified Queries |

---

## Data Model & Cryptic Banking Schema

[`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql) transforms the public **CFPB Consumer Complaint Database** (`bigquery-public-data.cfpb_complaints.complaint_database`, `2018-01-01` to `2022-12-31`) into two analytical tables inside `finserv_risk_ops` (**2,275,283** total dispute cases, **336,345** Reg E qualifying electronic payment/deposit/card disputes, and **16,407** daily product-line rollup rows across 9 product lines):

```
bigquery-public-data.cfpb_complaints.complaint_database  (Location: US)
        |
        |  sql/01_setup_finserv_risk_mart.sql
        v
finserv_risk_ops.fct_consumer_disputes  (PARTITION BY DATE_TRUNC(intake_dt, MONTH), CLUSTER BY prod_line_cd, subm_chnl_cd, jur_state_cd)
        ├── dispute_case_id      (STRING)   Unique dispute case identifier
        ├── intake_dt            (DATE)     Dispute intake date (primary timeline column)
        ├── network_fwd_dt       (DATE)     Date forwarded to bank operations queue
        ├── prod_line_cd         (STRING)   Primary banking product line
        ├── sub_prod_cd          (STRING)   Granular sub-product category
        ├── iss_cat_cd           (STRING)   Primary dispute reason category
        ├── sub_iss_cd           (STRING)   Secondary dispute reason code
        ├── subm_chnl_cd         (STRING)   Intake submission channel ('Web', 'Referral', 'Phone', 'Postal mail', 'Fax')
        ├── inst_name            (STRING)   Financial institution name
        ├── jur_state_cd         (STRING)   Two-letter US state code
        ├── jur_zip_cd           (STRING)   Consumer ZIP code
        ├── vuln_cohort_tag      (STRING)   Vulnerable cohort tag ('Older American', 'Servicemember', 'StandardCohort')
        ├── res_disp_cd          (STRING)   Resolution disposition code
        ├── sla_breach_flg       (INT64)    1 = Untimely response SLA breach; 0 = Compliant
        ├── cust_esc_tier2_flg   (INT64)    1 = Escalated to Tier-2 supervisory review; 0 = Tier-1
        ├── mon_rel_ind          (INT64)    1 = Closed with monetary relief reimbursement; 0 = Other
        ├── reg_e_elig_flg       (INT64)    1 = Regulation E (deposit/card/money-transfer/EFT) scope; 0 = Non-Reg E
        ├── intake_fwd_lag_days  (INT64)    Routing lag in days between intake_dt and network_fwd_dt (clamped to [0, 90])
        └── est_ops_cost_usd     (NUMERIC)  Deterministic operational servicing & settlement cost in USD
        |
        v
finserv_risk_ops.agg_daily_risk_kpis    (PARTITION BY DATE_TRUNC(intake_dt, MONTH), CLUSTER BY prod_line_cd)
        ├── intake_dt                    (DATE)
        ├── prod_line_cd                 (STRING)
        ├── daily_dispute_vol            (INT64)
        ├── reg_e_dispute_vol            (INT64)
        ├── avg_intake_fwd_lag_days      (FLOAT64)
        ├── tier2_escalation_rate_pct    (FLOAT64)
        ├── monetary_relief_rate_pct     (FLOAT64)
        ├── sla_breach_rate_pct          (FLOAT64)
        ├── total_ops_cost_usd           (FLOAT64)
        └── avg_ops_cost_per_dispute_usd (FLOAT64)
```

---

## Step-by-Step Deployment (Google Cloud Console — Preferred)

Every step below uses the **Google Cloud Console** and works in any GCP project without modifying a single line of SQL.

### Step 1 — Build the FinServ Risk Mart ([`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql))

1. Open the Google Cloud Console and navigate to **BigQuery → Studio**.
2. Click **+ SQL query**, paste the contents of [`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql), and click **Run** (~8–15 seconds).
   * *Note:* The script automatically executes `CREATE SCHEMA IF NOT EXISTS finserv_risk_ops OPTIONS (location = 'US')`, so you do not even need to create the dataset manually first.
3. **Verify:** Expand `finserv_risk_ops` in the left Explorer pane, click `fct_consumer_disputes` → **Schema** tab, and observe the cryptic column names (`reg_e_elig_flg`, `cust_esc_tier2_flg`, `mon_rel_ind`) with blank descriptions.

---

### Step 2 — Act 1: Run Trend, Seasonality & Operational Cost Correlations ([`sql/02_act1_baseline_trend_seasonality_correlation.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql))

1. Open a new SQL tab in BigQuery Studio, paste [`sql/02_act1_baseline_trend_seasonality_correlation.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql), and click **Run**.
2. **Inspect the three query results:**
   * **Query 1A (`ML.TREND`):** Extracts `smoothed_long_term_trend` (`ROUND(trend, 2)`) on `total_reg_e_disputes` using `smoothing_window_size => 14` and `adjust_step_changes => TRUE`.
   * **Query 1B (`ML.SEASONALITY`):** Decomposes `total_reg_e_disputes` into `yearly_seasonality_effect`, `monthly_seasonality_effect`, and `weekly_seasonality_effect` (`seasonalities => ['Yearly', 'Monthly', 'Weekly']`).
   * **Query 1C (`ML.CORRELATION`):** Computes the Pearson correlation (`correlation`) between `total_ops_cost_usd` (`target_col`) and five operational risk KPIs sliced by `dimension_cols => ['prod_line_cd']` (filtering `AND NOT IS_NAN(correlation)`). Confirms that `reg_e_dispute_vol` is the #1 operational cost driver in `Credit card or prepaid card` (**`r = 0.9601`**), `Money transfer, virtual currency, or money service` (**`r = 0.9536`**), and `Checking or savings account` (**`r = 0.9163`**).

---

### Step 3 — Act 2: Chain `ML.DETECT_CHANGE_POINTS` into `AI.KEY_DRIVERS` ([`sql/03_act2_change_points_and_key_drivers_chain.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql))

1. Open a new SQL tab, paste [`sql/03_act2_change_points_and_key_drivers_chain.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql), and click **Run**.
2. **Inspect the two query results:**
   * **Query 2A (`ML.DETECT_CHANGE_POINTS`):** Pinpoints two statistically significant structural surge regimes in daily Reg E disputes: **`2020-05-26` to `2020-06-05`** (11 days, averaging **242.0 disputes/day**) and **`2022-05-01` to `2022-05-16`** (16 days, averaging **200.9 disputes/day**, peaking at **340.0/day**).
   * **Query 2B (`ML.DETECT_CHANGE_POINTS` → `AI.KEY_DRIVERS`):** Dynamically selects the highest-average regime breakpoint (`shift_date = 2020-05-26`), labels a $\pm 60$-day window around `shift_date` (`is_post_shift`), and runs `AI.KEY_DRIVERS` (`enable_pruning => TRUE`, `top_k => 15`) across 5 dimensions. Surfaces `Money transfer, virtual currency, or money service` (**`+86.3%` growth, `+915.2` unexpected excess disputes**; **`+91.7%`** via `Web`) and `Checking or savings account` (**`+31.7%` growth, `+596.0` unexpected excess disputes**) as the primary root causes of the `+21.0%` (`+2,329` dispute) surge.

---

### Step 4 — Act 3: Quantify Counterfactual Impact with `AI.CAUSAL_EFFECT` ([`sql/04_act3_intervention_causal_effect.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql))

1. Open a new SQL tab, paste [`sql/04_act3_intervention_causal_effect.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql), and click **Run**.
2. **Inspect the three query results (evaluating the July 1, 2020 P2P & Web fraud-control rollout):**
   * **Query 3A (`output_time_series => FALSE`):** Proves that the July 1, 2020 intervention prevented **`-4,694` cumulative Reg E disputes** relative to the synthetic pre-intervention counterfactual (**`-20.31%` relative reduction, `93.56%` posterior causal confidence, `p = 0.064447`**).
   * **Query 3B (`output_time_series => TRUE`):** Outputs the pointwise time series (`total_reg_e_disputes`, `predicted_counterfactual_disputes`, `counterfactual_lower_95`, `counterfactual_upper_95`). Switch the BigQuery Studio results pane from **Table** to **Chart** (Line chart) to visualize observed vs. counterfactual volume!
   * **Query 3C (`id_cols => ['prod_line_cd']`):** Runs parallel counterfactual models per banking product line, proving that the largest statistically significant cost reduction occurred in **`Money transfer, virtual currency, or money service`** (**`-$205,510.65` cumulative savings, `-34.38%`, `91.12%` causal confidence, `p = 0.0888`**).

---

### Step 5 — Observe the "Before Grounding" Context Gap in BQCA

1. In **BigQuery Studio**, open **Conversational Analytics / Agents** and start a **Direct Conversation** pointed only at the un-enriched `finserv_risk_ops.fct_consumer_disputes` table (before running [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql)).
2. Ask the prompt from [**`docs/knowledge_catalog_and_bqca_assets.md` (Section 4, Phase A)**](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md#phase-a-the-before-grounding-test-direct-chat-on-raw-cryptic-table):
   > *"What is the long-term trend and yearly seasonality of our daily Reg E qualifying disputes, and which intake channels and sub-products drove the biggest structural shift in Tier-2 escalations?"*
3. **Observe the failure:** Because column descriptions are blank, the ungrounded session guesses what *"Reg E qualifying dispute"* (`reg_e_elig_flg`) and *"Tier-2 escalation"* (`cust_esc_tier2_flg`) mean—often filtering on `iss_cat_cd LIKE '%Reg E%'` (which returns `0` rows!) or writing manual window functions instead of invoking the 6 TVFs.

---

### Step 6 — Enrich Metadata & Configure Knowledge Catalog ([`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql))

1. **Enrich Schema Metadata via SQL:** Open a BigQuery Studio SQL tab, paste [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql), and click **Run**. Refresh `fct_consumer_disputes` and `agg_daily_risk_kpis` → **Schema** to see the authoritative business descriptions on all 28 columns.
2. **Generate Data Profile & Data Insights:** On both tables, open the **Data profile** and **Insights** tabs in BigQuery Studio and click **Generate**.
3. **Create the Business Glossary (`FinServ_Risk_Glossary`):**
   * Navigate to **Dataplex → Knowledge Catalog → Glossaries** in the Console.
   * Create `FinServ_Risk_Glossary` and add the **6 Business Glossary Terms** from [**`docs/knowledge_catalog_and_bqca_assets.md` (Section 1)**](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md#1-knowledge-catalog-business-glossary-terms-finserv_risk_glossary), linking each term to its physical columns in `fct_consumer_disputes` and `agg_daily_risk_kpis`.

---

### Step 7 — Configure `FinServ_Payments_Risk_Agent` & Audit via `INFORMATION_SCHEMA` ([`sql/06_audit_bqca_agent_jobs.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/06_audit_bqca_agent_jobs.sql))

1. In **BigQuery → Agents**, create or edit **`FinServ_Payments_Risk_Agent`** attached to both `finserv_risk_ops.fct_consumer_disputes` and `finserv_risk_ops.agg_daily_risk_kpis`.
2. Paste the **Agent Instructions** from [**`docs/knowledge_catalog_and_bqca_assets.md` (Section 2)**](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md#2-bqca-data-agent-configuration-finserv_payments_risk_agent) and add the **3 Verified Queries** from [**Section 3**](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md#3-verified-queries-copy-paste-into-the-verified-queries-section).
3. Run the 3-turn executive conversation from [**Section 4, Phase B**](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/docs/knowledge_catalog_and_bqca_assets.md#phase-b-the-after-grounding-3-turn-executive-investigation-in-finserv_payments_risk_agent).
4. **Audit the Agent's SQL Execution:** Open a SQL tab, paste [`sql/06_audit_bqca_agent_jobs.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/06_audit_bqca_agent_jobs.sql), and click **Run** to verify in `` `region-us`.INFORMATION_SCHEMA.JOBS `` (`ca-bq-job = 'true'`) which Augmented Analytics TVFs were executed.

---

## Verifying It Worked

### 1. Confirm Both Tables Are Populated

```sql
SELECT
  COUNT(*) AS total_disputes,
  SUM(reg_e_elig_flg) AS reg_e_disputes,
  SUM(cust_esc_tier2_flg) AS tier2_escalations,
  SUM(mon_rel_ind) AS monetary_relief_cases
FROM finserv_risk_ops.fct_consumer_disputes;
-- Expected: 2,275,283 total_disputes | 336,345 reg_e_disputes | 56,746 tier2_escalations | 67,220 monetary_relief_cases
```

### 2. Confirm All 28 Column Descriptions Are Populated in `INFORMATION_SCHEMA`

```sql
SELECT
  table_name,
  column_name,
  data_type,
  description
FROM `finserv_risk_ops.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE description IS NOT NULL
ORDER BY table_name, column_name;
```

---

## Troubleshooting & SQL Gotchas

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `Not found: Dataset ...:finserv_risk_ops was not found in location ...` | Query editor location is set to a single region (e.g., `us-central1`) instead of `US` | In BigQuery Studio **Query settings → Additional settings → Data location**, select **`US`** (or leave on default automatic) |
| `Table-valued function not found: <project>.AI.KEY_DRIVERS` | You prefixed `AI.*` or `ML.*` with a project or dataset name | Never qualify built-in `AI.*` or `ML.*` TVFs with a project/dataset prefix; only qualify the input `TABLE finserv_risk_ops.<table_name>` inside the parentheses |
| `Only one of min_apriori_support and top_k can be set` in `AI.KEY_DRIVERS` | Passing both `top_k` and `min_apriori_support` simultaneously | Specify either `top_k => 15` or `min_apriori_support => 0.02`, never both in the same `AI.KEY_DRIVERS` call |
| `AI.CAUSAL_EFFECT expects the intervention_timestamp argument to be a TIMESTAMP literal` | Passing a `@parameter` or runtime `TIMESTAMP(col)` expression into `intervention_timestamp` | Always pass a compile-time `TIMESTAMP` literal (e.g., `intervention_timestamp => '2020-07-01 00:00:00'`) |
| `The 'interest_label_col' column must contain at least one TRUE value and at least one FALSE value` in `AI.KEY_DRIVERS` | The upstream CTE (`primary_surge_breakpoint`) filtered out all regimes or picked a boundary date | Filter `ML.DETECT_CHANGE_POINTS` with `WHERE begin_timestamp IS NOT NULL` as shown in [`sql/03_act2_change_points_and_key_drivers_chain.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/03_act2_change_points_and_key_drivers_chain.sql) |
| `NaN` values in `ML.CORRELATION` output | Product lines with zero variance on a metric (e.g., `reg_e_dispute_vol = 0` for `Debt collection`) produce `NaN` Pearson correlation | Filter with `WHERE segment_size >= 100 AND NOT IS_NAN(correlation)` as shown in [`sql/02_act1_baseline_trend_seasonality_correlation.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql) |
| BQCA Agent still guesses column names after running [`sql/05_enrich_metadata_for_knowledge_catalog.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/05_enrich_metadata_for_knowledge_catalog.sql) | Existing chat session cached the pre-enrichment schema | Start a **New Conversation** so the agent reloads the updated `INFORMATION_SCHEMA` and Knowledge Catalog metadata |

---

## Cost Breakdown & Cleanup

* **Estimated Cost:** **$0.00** within BigQuery's 1 TiB/month free query tier and 10 GiB/month free storage tier ([`sql/01_setup_finserv_risk_mart.sql`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/01_setup_finserv_risk_mart.sql) scans ~1.2 GB once; [`sql/02`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/02_act1_baseline_trend_seasonality_correlation.sql)–[`sql/04`](https://github.com/Rajdipc/bq-agentic-analytics-finserv-tvfs/blob/main/sql/04_act3_intervention_causal_effect.sql) scan < 150 MB total; $0.00 when idle).
* **Cleanup:** Delete the `finserv_risk_ops` dataset in BigQuery Studio (or run `bq rm -r -f -d finserv_risk_ops` in Cloud Shell), delete `FinServ_Payments_Risk_Agent` in **BigQuery → Agents**, and delete `FinServ_Risk_Glossary` in **Knowledge Catalog → Glossaries**.
