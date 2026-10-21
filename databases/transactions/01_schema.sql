-- NexaBank Transactions Database (core payments)
-- Note: customer_id points at a customer in a *different* database (CRM).
-- No FK can express that, which is exactly why lineage/catalog tooling is needed.

CREATE SCHEMA payments;

CREATE TABLE payments.accounts (
    account_id    integer PRIMARY KEY,
    customer_id   integer NOT NULL,
    iban          varchar(34),
    account_type  varchar(15),
    currency      char(3),
    opened_at     date,
    status        varchar(10)
);

CREATE TABLE payments.transactions (
    txn_id                bigint PRIMARY KEY,
    account_id            integer NOT NULL REFERENCES payments.accounts,
    txn_ts                timestamp NOT NULL,
    amount                double precision,  -- not numeric: OpenMetadata 2.0.5 range tests reject NUMERIC columns
    currency              char(3),
    channel               varchar(10),
    merchant_name         varchar(80),
    merchant_category     varchar(30),
    counterparty_country  char(2),
    card_number           varchar(19),
    is_fraud              boolean NOT NULL
);

-- Luhn-valid synthetic card numbers (so PII scanners recognise them as card numbers)
CREATE FUNCTION public.luhn(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT p || ((10 - sum(CASE WHEN i % 2 = 1 THEN (CASE WHEN 2*x > 9 THEN 2*x - 9 ELSE 2*x END) ELSE x END) % 10) % 10)::text
    FROM (SELECT substr(reverse(p), i, 1)::int AS x, i FROM generate_series(1, length(p)) i) d
$$;

-- Synthetic transaction generator, used by the seed script (02_seed.sql).
CREATE FUNCTION public.simulate_transactions(p_first_id bigint, p_n int, p_start timestamp,
                                             p_days int, p_seed float8)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE n_acc int;
BEGIN
    PERFORM setseed(p_seed);
    SELECT count(*) INTO n_acc FROM payments.accounts;

    INSERT INTO payments.transactions
    SELECT id, account_id, ts,
           CASE WHEN r_neg < 0.003 THEN -amt ELSE amt END,                  -- defect: sign error
           CASE WHEN r_cur < 0.002 THEN 'XXX' ELSE currency END,           -- defect: invalid currency
           channel, merchant,
           CASE WHEN r_cat < 0.01 THEN NULL ELSE category END,             -- defect: missing category
           cc,
           CASE WHEN channel <> 'ATM' THEN luhn('4539' || lpad((account_id * 7919)::text, 11, '0')) END,
           r_fraud < 0.004 + 0.05 * (cc <> 'GB')::int
                           + 0.04 * (category IN ('ELECTRONICS','GAMBLING','CRYPTO'))::int
                           + 0.04 * (extract(hour FROM ts) < 5)::int
                           + 0.03 * (amt > 300)::int
                           + 0.02 * (channel = 'ONLINE')::int
    FROM (
        SELECT d.*, a.currency,
               (ARRAY['GROCERIES','RESTAURANTS','TRAVEL','FUEL','UTILITIES','ELECTRONICS',
                      'ONLINE_RETAIL','GAMBLING','CRYPTO','CASH_WITHDRAWAL'])[1 + ci] AS category,
               (ARRAY['FreshMart','Bistro 21','SkyTrips','QuickFuel','PowerGrid Energy','Volt Electronics',
                      'ShopSphere','LuckyBet','CoinVault','NexaBank ATM'])[1 + ci] AS merchant,
               CASE WHEN ci = 9 THEN 'ATM'
                    ELSE (ARRAY['CARD','CARD','ONLINE','MOBILE','BRANCH'])[1 + floor(r_ch * 5)::int] END AS channel,
               round((exp(2.6 + 1.1 * sqrt(-2 * ln(u1)) * cos(2 * pi() * u2)))::numeric, 2)::float8 AS amt
        FROM (
            SELECT p_first_id + g - 1 AS id,
                   1 + floor(random() * n_acc)::int AS account_id,
                   p_start + random() * (p_days || ' days')::interval AS ts,
                   floor(random() * 10)::int AS ci,
                   CASE WHEN random() < 0.12
                        THEN (ARRAY['FR','DE','ES','NG','RU','US','AE','CN'])[1 + floor(random() * 8)::int]
                        ELSE 'GB' END AS cc,
                   1 - random() AS u1, random() AS u2, random() AS r_ch,
                   random() AS r_neg, random() AS r_cur, random() AS r_cat, random() AS r_fraud
            FROM generate_series(1, p_n) g
        ) d
        JOIN payments.accounts a USING (account_id)
    ) t;

    -- defect: ~0.1% duplicate postings (same account, time, amount; new txn_id)
    INSERT INTO payments.transactions
    SELECT p_first_id + p_n + row_number() OVER (ORDER BY txn_id) - 1,
           account_id, txn_ts, amount, currency, channel, merchant_name, merchant_category,
           counterparty_country, card_number, is_fraud
    FROM payments.transactions
    WHERE txn_id BETWEEN p_first_id AND p_first_id + p_n - 1 AND txn_id % 1000 = 7;

    RETURN (SELECT max(txn_id) FROM payments.transactions);
END $$;

CREATE ROLE om_reader LOGIN PASSWORD 'om_reader_pw';
GRANT USAGE ON SCHEMA payments TO om_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA payments TO om_reader;
