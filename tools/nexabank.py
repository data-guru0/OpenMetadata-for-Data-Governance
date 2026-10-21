"""NexaBank data platform: the nightly ETL (CRM + Payments -> analytics_db) and a data reset.

The SQL below is the single source of truth: run_etl() executes it, and openmeta.register_etl_lineage()
sends the same SQL + column mappings to OpenMetadata.
"""
import time

import psycopg2
from psycopg2.extras import execute_values

DBS = {
    "customers": dict(host="nexabank-customers-db", dbname="customers_db", user="crm_admin", password="crm_admin_pw"),
    "transactions": dict(host="nexabank-transactions-db", dbname="transactions_db", user="payments_admin", password="payments_admin_pw"),
    "analytics": dict(host="nexabank-analytics-db", dbname="analytics_db", user="analytics_admin", password="analytics_admin_pw"),
}

# ---------------------------------------------------------------------------------------------
# ETL definition. The SQL below is the single source of truth: the ETL executes it, and
# openmeta.register_etl_lineage() sends the same SQL + column mappings to OpenMetadata.
# ---------------------------------------------------------------------------------------------
EXTRACT_CUSTOMERS = """SELECT c.customer_id, c.seg_cd, c.country,
       CASE WHEN c.date_of_birth IS NULL OR c.date_of_birth > DATE '2026-09-30' THEN 'UNKNOWN'
            WHEN c.date_of_birth > DATE '2001-09-30' THEN '18-24'
            WHEN c.date_of_birth > DATE '1986-09-30' THEN '25-39'
            WHEN c.date_of_birth > DATE '1966-09-30' THEN '40-59'
            ELSE '60+' END AS age_band,
       k.status AS kyc_status, k.pep_flag, k.sanctions_hit, c.created_at::date AS customer_since
FROM crm.customers c
LEFT JOIN crm.kyc_verifications k ON k.customer_id = c.customer_id"""

EXTRACT_TRANSACTIONS = """SELECT t.txn_id, a.customer_id, a.account_type, t.txn_ts, t.amount, t.currency, t.channel,
       t.merchant_category, t.counterparty_country, t.card_number, t.is_fraud
FROM payments.transactions t
JOIN payments.accounts a ON a.account_id = t.account_id"""

# These run *inside* analytics_db, so they land in pg_stat_statements and OpenMetadata's
# lineage agent can parse them automatically (query-log lineage).
BUILD_RISK_SCORES = """INSERT INTO marts.customer_risk_scores
    (customer_id, seg_cd, country, kyc_status, txn_count, total_spend, foreign_txn_ratio, risk_score, risk_tier)
SELECT customer_id, seg_cd, country, kyc_status, txn_count, total_spend, foreign_txn_ratio, risk_score,
       CASE WHEN risk_score >= 60 THEN 'HIGH' WHEN risk_score >= 30 THEN 'MEDIUM' ELSE 'LOW' END
FROM (
    SELECT c.customer_id, c.seg_cd, c.country, c.kyc_status,
           count(t.txn_id) AS txn_count,
           coalesce(sum(t.amount), 0) AS total_spend,
           coalesce(avg((t.counterparty_country <> 'GB')::int), 0) AS foreign_txn_ratio,
           least(100, 40 * c.sanctions_hit::int + 25 * c.pep_flag::int
                      + CASE WHEN c.kyc_status = 'VERIFIED' THEN 0 ELSE 20 END
                      + round(100 * coalesce(avg((t.counterparty_country <> 'GB')::int), 0))::int) AS risk_score
    FROM staging.stg_customers c
    LEFT JOIN staging.stg_transactions t ON t.customer_id = c.customer_id
    GROUP BY c.customer_id, c.seg_cd, c.country, c.kyc_status, c.pep_flag, c.sanctions_hit
) s"""

BUILD_FRAUD_FEATURES = """INSERT INTO marts.fraud_training_features
    (txn_id, txn_ts, amount, txn_hour, is_foreign, channel, merchant_category, account_type,
     customer_age_band, customer_risk_tier, card_number, is_fraud)
SELECT t.txn_id, t.txn_ts, t.amount, extract(hour FROM t.txn_ts)::int, t.counterparty_country <> 'GB',
       t.channel, t.merchant_category, t.account_type, c.age_band, r.risk_tier, t.card_number, t.is_fraud
FROM staging.stg_transactions t
JOIN staging.stg_customers c ON c.customer_id = t.customer_id
JOIN marts.customer_risk_scores r ON r.customer_id = t.customer_id"""

STG_CUSTOMER_COLS = ["customer_id", "seg_cd", "country", "age_band", "kyc_status", "pep_flag", "sanctions_hit", "customer_since"]
STG_TXN_COLS = ["txn_id", "customer_id", "account_type", "txn_ts", "amount", "currency", "channel",
                "merchant_category", "counterparty_country", "card_number", "is_fraud"]


def connect(db, retries=30):
    for i in range(retries):
        try:
            conn = psycopg2.connect(**DBS[db], connect_timeout=3)
            conn.autocommit = True
            return conn
        except psycopg2.OperationalError:
            if i == retries - 1:
                raise
            time.sleep(2)


def run_etl():
    with connect("customers") as src, src.cursor() as cur:
        cur.execute(EXTRACT_CUSTOMERS)
        customers = cur.fetchall()
    with connect("transactions") as src, src.cursor() as cur:
        cur.execute(EXTRACT_TRANSACTIONS)
        txns = cur.fetchall()
    print(f"extracted {len(customers)} customers (no names/emails/IDs) and {len(txns)} transactions")
    with connect("analytics") as dst, dst.cursor() as cur:
        cur.execute("TRUNCATE staging.stg_customers, staging.stg_transactions, marts.customer_risk_scores, marts.fraud_training_features")
        execute_values(cur, f"INSERT INTO staging.stg_customers ({','.join(STG_CUSTOMER_COLS)}) VALUES %s", customers, page_size=5000)
        execute_values(cur, f"INSERT INTO staging.stg_transactions ({','.join(STG_TXN_COLS)}) VALUES %s", txns, page_size=5000)
        print("loaded staging.stg_customers, staging.stg_transactions")
        # in-database SQL: lands in pg_stat_statements, so OpenMetadata derives staging -> marts lineage itself
        for name, sql in [("marts.customer_risk_scores", BUILD_RISK_SCORES), ("marts.fraud_training_features", BUILD_FRAUD_FEATURES)]:
            cur.execute(sql)
            print(f"built {name}: {cur.statusmessage}")


def reset_data():
    for db in ("customers", "transactions"):
        with connect(db) as conn, conn.cursor() as cur:
            cur.execute(open(f"/databases/{db}/02_seed.sql", encoding="utf-8").read())
        print(f"{db}_db re-seeded from databases/{db}/02_seed.sql")
    run_etl()


def analytics_ready():
    with connect("analytics") as conn, conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM marts.fraud_training_features")
        return cur.fetchone()[0] > 0
