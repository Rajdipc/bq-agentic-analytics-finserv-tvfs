#!/usr/bin/env python3
"""Creates the 6 FinServ_Risk_Glossary terms and links them to 13 BigQuery columns.

Uses only the Python standard library and `gcloud` CLI credentials—no pip
packages or hardcoded GCP project IDs required.

Why this script exists:
  In the Google Cloud Console, creating an empty Business Glossary named
  `FinServ_Risk_Glossary` in Knowledge Catalog (`locations/us`) is easy,
  but manually creating 6 terms and binding them to 13 physical BigQuery
  columns across `fct_consumer_disputes` and `agg_daily_risk_kpis` can be
  tedious or unavailable in the Console UI. Under the hood, column-to-term
  bindings are stored as Dataplex Universal Catalog `EntryLink` resources
  (`entryLinkTypes/definition`) in the `@bigquery` entry group.

Usage (in Cloud Shell or local terminal):
  python3 scripts/link_knowledge_catalog_glossary.py
"""

import json
import subprocess
import sys
import urllib.error
import urllib.request

LOCATION = "us"
DATASET_ID = "finserv_risk_ops"
GLOSSARY_DISPLAY_NAME = "FinServ_Risk_Glossary"
GLOSSARY_FALLBACK_ID = "finserv-risk-glossary"
DEFINITION_LINK_TYPE = (
    "projects/655216118709/locations/global/entryLinkTypes/definition"
)

TERMS = [
    {
        "term_id": "reg-e-qualifying-dispute",
        "display_name": "Reg E Qualifying Dispute",
        "description": (
            "A consumer dispute on an account or service covered by the Electronic "
            "Fund Transfer Act (Regulation E, 12 CFR 1005): checking/savings and "
            "other deposit services (excluding CDs), Reg E prepaid accounts "
            "(general-purpose, government benefit, payroll, student prepaid), "
            "mobile/digital wallets, and domestic or international money transfers. "
            "Credit cards are excluded (Regulation Z), as are gift cards, virtual "
            "currency, money orders, and check cashing. Identified in "
            "fct_consumer_disputes where reg_e_elig_flg = 1, and aggregated daily "
            "in agg_daily_risk_kpis.reg_e_dispute_vol. Synonyms: Reg E dispute, "
            "Regulation E claim, electronic fund transfer dispute, unauthorized EFT."
        ),
        "columns": [
            ("fct_consumer_disputes", "reg_e_elig_flg"),
            ("agg_daily_risk_kpis", "reg_e_dispute_vol"),
        ],
    },
    {
        "term_id": "tier-2-customer-escalation",
        "display_name": "Tier-2 Customer Escalation",
        "description": (
            "A proxy for disputes that needed specialist or supervisory review "
            "beyond Tier-1 intake: the institution breached the timely-response "
            "SLA, the response was marked untimely, or the issue is a fraud / scam "
            "/ unauthorized-transaction claim. (The CFPB consumer_disputed field is "
            "not used because it has not been published since April 2017.) "
            "Identified where cust_esc_tier2_flg = 1 and tracked as a daily "
            "percentage in agg_daily_risk_kpis.tier2_escalation_rate_pct. Synonyms: "
            "Tier-2 escalation, supervisory review, escalated dispute, specialist review."
        ),
        "columns": [
            ("fct_consumer_disputes", "cust_esc_tier2_flg"),
            ("agg_daily_risk_kpis", "tier2_escalation_rate_pct"),
        ],
    },
    {
        "term_id": "monetary-relief-ratio",
        "display_name": "Monetary Relief Ratio",
        "description": (
            "The percentage of consumer disputes closed with direct monetary "
            "reimbursement or fee reversal (res_disp_cd = 'Closed with monetary relief'). "
            "Tracked at the case level via mon_rel_ind = 1 and as a daily percentage "
            "in agg_daily_risk_kpis.monetary_relief_rate_pct. Synonyms: monetary "
            "relief rate, cash redress rate, upheld with financial relief, reimbursement rate."
        ),
        "columns": [
            ("fct_consumer_disputes", "mon_rel_ind"),
            ("agg_daily_risk_kpis", "monetary_relief_rate_pct"),
        ],
    },
    {
        "term_id": "intake-to-network-routing-lag",
        "display_name": "Intake-to-Network Routing Lag",
        "description": (
            "The number of calendar days elapsed between initial dispute intake "
            "(intake_dt) and forwarding to the bank's operational resolution queue "
            "(network_fwd_dt). Tracked at the case level in intake_fwd_lag_days and "
            "averaged daily in agg_daily_risk_kpis.avg_intake_fwd_lag_days. Synonyms: "
            "routing lag, forwarding lag, intake latency, queue routing delay."
        ),
        "columns": [
            ("fct_consumer_disputes", "intake_fwd_lag_days"),
            ("agg_daily_risk_kpis", "avg_intake_fwd_lag_days"),
        ],
    },
    {
        "term_id": "regulatory-sla-breach",
        "display_name": "Regulatory SLA Breach",
        "description": (
            "Failure to provide a formal resolution within the mandated regulatory "
            "response window (timely_response = FALSE). Identified where "
            "sla_breach_flg = 1 and tracked as a daily percentage in "
            "agg_daily_risk_kpis.sla_breach_rate_pct. Synonyms: SLA breach, "
            "untimely response, late compliance response."
        ),
        "columns": [
            ("fct_consumer_disputes", "sla_breach_flg"),
            ("agg_daily_risk_kpis", "sla_breach_rate_pct"),
        ],
    },
    {
        "term_id": "dispute-operational-cost",
        "display_name": "Dispute Operational Cost",
        "description": (
            "Total estimated operational servicing and settlement processing cost in "
            "USD for handling consumer disputes, combining base intake cost ($45), "
            "Reg E compliance surcharge ($35), routing lag penalty ($8.50/day), "
            "Tier-2 review ($120), and monetary relief processing ($165). Synonyms: "
            "handling cost, ops cost, dispute servicing cost, cost per dispute."
        ),
        "columns": [
            ("fct_consumer_disputes", "est_ops_cost_usd"),
            ("agg_daily_risk_kpis", "total_ops_cost_usd"),
            ("agg_daily_risk_kpis", "avg_ops_cost_per_dispute_usd"),
        ],
    },
]


def get_gcloud_value(args):
    return subprocess.check_output(["gcloud"] + args, text=True).strip()


def api_request(method, url, token, project_id, payload=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Goog-User-Project": project_id,
        "Content-Type": "application/json",
    }
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="replace")
        return err.code, body


def find_or_create_glossary(project_id, token):
    base_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{LOCATION}/glossaries"
    status, resp = api_request("GET", base_url, token, project_id)
    if status != 200:
        sys.exit(f"Failed to list glossaries (HTTP {status}): {resp}")

    for g in resp.get("glossaries", []):
        if g.get("displayName") == GLOSSARY_DISPLAY_NAME or g.get("name", "").endswith(
            f"/{GLOSSARY_FALLBACK_ID}"
        ):
            print(f"[OK] Found existing glossary: {g['name']} ({g.get('displayName')})")
            return g["name"]

    print(f"[INFO] Creating glossary {GLOSSARY_DISPLAY_NAME} in locations/{LOCATION}...")
    create_url = f"{base_url}?glossaryId={GLOSSARY_FALLBACK_ID}"
    status, resp = api_request(
        "POST",
        create_url,
        token,
        project_id,
        {
            "displayName": GLOSSARY_DISPLAY_NAME,
            "description": (
                "Authoritative Consumer Banking, Payments Operations, and "
                "Regulation E (12 CFR 1005) dispute glossary for BigQuery "
                "Conversational Analytics."
            ),
        },
    )
    if status not in (200, 201):
        sys.exit(f"Failed to create glossary (HTTP {status}): {resp}")
    glossary_name = f"projects/{project_id}/locations/{LOCATION}/glossaries/{GLOSSARY_FALLBACK_ID}"
    print(f"[OK] Created glossary: {glossary_name}")
    return glossary_name


def ensure_terms_and_links(project_id, project_number, token, glossary_name):
    glossary_id = glossary_name.split("/")[-1]
    for term in TERMS:
        term_id = term["term_id"]
        create_url = f"https://dataplex.googleapis.com/v1/{glossary_name}/terms?termId={term_id}"
        payload = {
            "parent": glossary_name,
            "displayName": term["display_name"],
            "description": term["description"],
        }
        status, resp = api_request("POST", create_url, token, project_id, payload)
        if status in (200, 201):
            print(f"[OK] Created term: {term['display_name']} ({term_id})")
        elif status == 409 or "already exists" in str(resp).lower():
            print(f"[OK] Term already exists: {term['display_name']} ({term_id})")
        else:
            sys.exit(f"Failed to create term {term_id} (HTTP {status}): {resp}")

        # IMPORTANT: Dataplex requires the @dataplex entry ID for a glossary term
        # to use the numeric project_number (not the string project_id), otherwise
        # it raises GLOSSARY_TERM_ENTRY_ID_CONTAINS_PROJECT_ID_ERROR.
        target_entry = (
            f"projects/{project_id}/locations/{LOCATION}/entryGroups/@dataplex/"
            f"entries/projects/{project_number}/locations/{LOCATION}/glossaries/"
            f"{glossary_id}/terms/{term_id}"
        )

        for table_name, col_name in term["columns"]:
            source_entry = (
                f"projects/{project_id}/locations/{LOCATION}/entryGroups/@bigquery/"
                f"entries/bigquery.googleapis.com/projects/{project_id}/datasets/"
                f"{DATASET_ID}/tables/{table_name}"
            )
            short_tbl = "fct" if "fct" in table_name else "agg"
            link_id = f"def-{short_tbl}-{col_name.replace('_', '-')}"[:63].rstrip("-")
            link_url = (
                f"https://dataplex.googleapis.com/v1/projects/{project_id}/"
                f"locations/{LOCATION}/entryGroups/@bigquery/entryLinks"
                f"?entryLinkId={link_id}"
            )
            link_payload = {
                "entryLinkType": DEFINITION_LINK_TYPE,
                "entryReferences": [
                    {"name": source_entry, "path": f"Schema.{col_name}", "type": "SOURCE"},
                    {"name": target_entry, "type": "TARGET"},
                ],
            }
            l_status, l_resp = api_request("POST", link_url, token, project_id, link_payload)
            if l_status in (200, 201):
                print(f"  -> Linked {table_name}.{col_name} ==> {term['display_name']}")
            elif l_status == 409 or "already exists" in str(l_resp).lower():
                print(f"  -> Already linked: {table_name}.{col_name} ==> {term['display_name']}")
            else:
                sys.exit(
                    f"Failed to link {table_name}.{col_name} (HTTP {l_status}): {l_resp}"
                )


def main():
    project_id = (
        sys.argv[1]
        if len(sys.argv) > 1
        else get_gcloud_value(["config", "get-value", "project"])
    )
    if not project_id or project_id == "(unset)":
        sys.exit(
            "Error: No active GCP project found. Run `gcloud config set project <PROJECT_ID>` "
            "or pass the project ID as the first argument."
        )
    project_number = get_gcloud_value(
        ["projects", "describe", project_id, "--format=value(projectNumber)"]
    )
    token = get_gcloud_value(["auth", "print-access-token"])
    print(f"Target GCP Project: {project_id} (number: {project_number}, location: {LOCATION})")
    glossary_name = find_or_create_glossary(project_id, token)
    ensure_terms_and_links(project_id, project_number, token, glossary_name)
    print("\nCompleted! All 6 FinServ_Risk_Glossary terms and 13 BigQuery column links are active.")


if __name__ == "__main__":
    main()
