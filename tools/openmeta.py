"""Small OpenMetadata helper (plain REST calls, no SDK).

  * register_etl_lineage(): declares the cross-database ETL hops (no connector can see them) as lineage
  * wipe():                 removes everything DEMO.md creates, for the next batch
"""
import base64
import os

import requests

import nexabank

OM_URL = os.environ.get("OM_URL", "http://openmetadata-server:8585")
API = OM_URL + "/api/v1"

# Service names the teacher types in the OpenMetadata UI (see DEMO.md).
SVC = {"customers": "nexabank_customers", "transactions": "nexabank_transactions", "analytics": "nexabank_analytics"}
DB = {"customers": "customers_db", "transactions": "transactions_db", "analytics": "analytics_db"}
PIPELINE_SERVICE, PIPELINE = "nexabank_etl", "nightly_analytics_load"


def fqn(db, schema_table):
    return f"{SVC[db]}.{DB[db]}.{schema_table}"



# Cross-database ETL hops: (source table, target table, SQL, {target column: [source columns]})
ETL_EDGES = [
    (fqn("customers", "crm.customers"), fqn("analytics", "staging.stg_customers"), nexabank.EXTRACT_CUSTOMERS,
     {"customer_id": ["customer_id"], "seg_cd": ["seg_cd"], "country": ["country"],
      "age_band": ["date_of_birth"], "customer_since": ["created_at"]}),
    (fqn("customers", "crm.kyc_verifications"), fqn("analytics", "staging.stg_customers"), nexabank.EXTRACT_CUSTOMERS,
     {"kyc_status": ["status"], "pep_flag": ["pep_flag"], "sanctions_hit": ["sanctions_hit"]}),
    (fqn("transactions", "payments.transactions"), fqn("analytics", "staging.stg_transactions"), nexabank.EXTRACT_TRANSACTIONS,
     {c: [c] for c in ["txn_id", "txn_ts", "amount", "currency", "channel", "merchant_category",
                       "counterparty_country", "card_number", "is_fraud"]}),
    (fqn("transactions", "payments.accounts"), fqn("analytics", "staging.stg_transactions"), nexabank.EXTRACT_TRANSACTIONS,
     {"customer_id": ["customer_id"], "account_type": ["account_type"]}),
]

_token = None


class OMError(Exception):
    pass


def call(method, path, json=None, params=None, ok404=False):
    global _token
    if _token is None:
        pw = base64.b64encode(os.environ.get("OM_ADMIN_PASSWORD", "admin").encode()).decode()
        r = requests.post(API + "/users/login", json={"email": os.environ.get("OM_ADMIN_EMAIL", "admin@open-metadata.org"),
                                                      "password": pw}, timeout=15)
        if r.status_code != 200:
            raise OMError(f"OpenMetadata login failed ({r.status_code}). Is it running at {OM_URL}?")
        _token = r.json()["accessToken"]
    r = requests.request(method, API + path, json=json, params=params, timeout=60,
                         headers={"Authorization": f"Bearer {_token}"})
    if r.status_code == 401:
        _token = None
        return call(method, path, json, params, ok404)
    if r.status_code == 404 and ok404:
        return None
    if r.status_code >= 400:
        raise OMError(f"{method} {path} -> {r.status_code}: {r.text[:400]}")
    return r.json() if r.content else {}


def table(name, fields="owners,tags,columns,domains,dataProducts"):
    return call("GET", f"/tables/name/{name}", params={"fields": fields}, ok404=True)



# ------------------------------------------------------------------ lineage for the cross-DB ETL
def ensure_pipeline():
    svc = {"name": PIPELINE_SERVICE, "serviceType": "CustomPipeline",
           "description": "NexaBank in-house Python ETL (tools/nexabank.py). Registered via the API, not discovered by a connector.",
           "connection": {"config": {"type": "CustomPipeline"}}}
    call("PUT", "/services/pipelineServices", svc)
    pipe = {"name": PIPELINE, "service": PIPELINE_SERVICE, "displayName": "Nightly analytics load",
            "description": "Extracts CRM and payments data, drops direct PII, loads `analytics_db.staging`, then builds the marts.",
            "tasks": [{"name": "extract_customers"}, {"name": "extract_transactions"},
                      {"name": "load_staging"}, {"name": "build_marts"}]}
    return call("PUT", "/pipelines", pipe), svc, pipe


def register_etl_lineage():
    missing = [t for t in {e[0] for e in ETL_EDGES} | {e[1] for e in ETL_EDGES} if table(t, "columns") is None]
    if missing:
        print("Not in the catalog yet:\n  " + "\n  ".join(sorted(missing)) +
              "\nCreate and ingest the 3 NexaBank services in OpenMetadata first (DEMO.md 1.2-1.3).")
        return
    pipeline = ensure_pipeline()[0]
    print(f"pipeline entity: {pipeline['fullyQualifiedName']}")
    for src, dst, sql, cols in ETL_EDGES:
        s, d = table(src, "columns"), table(dst, "columns")
        if s is None or d is None:
            print(f"SKIPPED {src} -> {dst}: not in the catalog yet (create and ingest the 3 services first)")
            continue
        call("PUT", "/lineage", {"edge": {
            "fromEntity": {"id": s["id"], "type": "table"},
            "toEntity": {"id": d["id"], "type": "table"},
            "lineageDetails": {
                "pipeline": {"id": pipeline["id"], "type": "pipeline"},
                "sqlQuery": sql,
                "source": "PipelineLineage",
                "description": "Cross-database load by the NexaBank nightly ETL (registered via API)",
                "columnsLineage": [{"fromColumns": [f"{src}.{c}" for c in srcs], "toColumn": f"{dst}.{tgt}"}
                                   for tgt, srcs in cols.items()],
            }}})
        print(f"lineage {src.split('.', 2)[2]} -> {dst.split('.', 2)[2]} ({len(cols)} column mappings)")


# ------------------------------------------------------------------ reset helper
# Names below are the ones DEMO.md asks the teacher to create.
WIPE = [
    ("services/databaseServices", n) for n in SVC.values()
] + [
    ("services/pipelineServices", PIPELINE_SERVICE),
    ("glossaries", "NexaBank_Banking_Glossary"), ("dataProducts", "Fraud_Detection_Data"),
    ("domains", "Retail_Banking"), ("classifications", "DataSensitivity"),
    ("teams", "Data_Platform"), ("teams", "Risk_Analytics"), ("teams", "Customer_Data"),
    ("roles", "PII_Restricted_Analyst"), ("policies", "Deny_PII_Data_Access"),
    ("users", "priya.sharma"), ("users", "david.chen"), ("users", "maria.lopez"),
]


def wipe():
    deleted = 0
    for kind, name in WIPE:
        found = call("GET", f"/{kind}/name/{name}", ok404=True)
        if found:
            call("DELETE", f"/{kind}/{found['id']}", params={"hardDelete": "true", "recursive": "true"})
            print(f"deleted {kind.split('/')[-1]}: {name}")
            deleted += 1
    print(f"{deleted} NexaBank objects removed from OpenMetadata")
