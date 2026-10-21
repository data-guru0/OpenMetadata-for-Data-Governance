-- Baseline data (re-runnable): ~3,000 accounts and Jun-Aug 2026 transactions.
TRUNCATE payments.transactions, payments.accounts;
SELECT setseed(0.7);

INSERT INTO payments.accounts
SELECT g,
       CASE WHEN g <= 2000 THEN g ELSE 1 + floor(random() * 2000)::int END,
       'GB' || lpad((g % 97)::text, 2, '0') || 'NEXA' || '400' || lpad((g * 31)::text, 3, '0') || lpad(g::text, 8, '0'),
       (ARRAY['CURRENT','CURRENT','SAVINGS','CREDIT_CARD'])[1 + floor(random() * 4)::int],
       CASE WHEN random() < 0.9 THEN 'GBP' ELSE 'EUR' END,
       date '2018-02-01' + floor(random() * 3000)::int,
       CASE WHEN random() < 0.95 THEN 'ACTIVE' ELSE 'CLOSED' END
FROM generate_series(1, 3000) g;

SELECT simulate_transactions(1, 45000, timestamp '2026-06-01', 92, 0.11);
