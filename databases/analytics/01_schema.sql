-- NexaBank Analytics Database
--   staging.*  <- loaded by the Python ETL from the CRM and Payments databases (cross-database hop)
--   marts.*    <- built by INSERT ... SELECT inside this database (visible in pg_stat_statements)
--   reports.*  <- views on top of the marts (view lineage)

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE SCHEMA staging;
CREATE SCHEMA marts;
CREATE SCHEMA reports;

CREATE TABLE staging.stg_customers (
    customer_id    integer PRIMARY KEY,
    seg_cd         char(1),
    country        char(2),
    age_band       varchar(10),
    kyc_status     varchar(10),
    pep_flag       boolean,
    sanctions_hit  boolean,
    customer_since date
);

CREATE TABLE staging.stg_transactions (
    txn_id                bigint PRIMARY KEY,
    customer_id           integer,
    account_type          varchar(15),
    txn_ts                timestamp,
    amount                double precision,
    currency              char(3),
    channel               varchar(10),
    merchant_category     varchar(30),
    counterparty_country  char(2),
    card_number           varchar(19),
    is_fraud              boolean
);

CREATE TABLE marts.customer_risk_scores (
    customer_id        integer PRIMARY KEY,
    seg_cd             char(1),
    country            char(2),
    kyc_status         varchar(10),
    txn_count          integer,
    total_spend        numeric(14,2),
    foreign_txn_ratio  numeric(5,4),
    risk_score         integer,
    risk_tier          varchar(6)
);

CREATE TABLE marts.fraud_training_features (
    txn_id              bigint PRIMARY KEY,
    txn_ts              timestamp,
    amount              double precision,
    txn_hour            integer,
    is_foreign          boolean,
    channel             varchar(10),
    merchant_category   varchar(30),
    account_type        varchar(15),
    customer_age_band   varchar(10),
    customer_risk_tier  varchar(6),
    card_number         varchar(19),
    is_fraud            boolean
);

CREATE VIEW reports.risk_report AS
SELECT risk_tier, country,
       count(*)                  AS customers,
       round(avg(risk_score), 1) AS avg_risk_score,
       sum(total_spend)          AS total_spend
FROM marts.customer_risk_scores
GROUP BY risk_tier, country;

CREATE VIEW reports.daily_fraud_kpis AS
SELECT txn_ts::date                   AS business_date,
       count(*)                       AS transactions,
       count(*) FILTER (WHERE is_fraud) AS fraud_transactions,
       sum(amount) FILTER (WHERE is_fraud) AS fraud_amount
FROM marts.fraud_training_features
GROUP BY txn_ts::date;

CREATE ROLE om_reader LOGIN PASSWORD 'om_reader_pw';
GRANT pg_read_all_stats TO om_reader;           -- lets OpenMetadata read query history for lineage
GRANT USAGE ON SCHEMA staging, marts, reports TO om_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA staging, marts, reports TO om_reader;
