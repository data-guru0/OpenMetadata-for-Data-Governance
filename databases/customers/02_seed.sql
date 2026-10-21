-- Deterministic synthetic customers (re-runnable: scripts/reset.ps1 -Level data runs this again).
-- Phone numbers use the UK Ofcom fictional range (07700 900xxx); emails use example.* domains.
-- Built-in quality defects: ~3% NULL email, ~1% malformed email, a few future birth dates,
-- and 10 duplicate customers (ids 1991-2000 copy ids 1-10).

TRUNCATE crm.kyc_verifications, crm.customers;
SELECT setseed(0.42);

INSERT INTO crm.customers
SELECT g,
       fn, ln,
       CASE WHEN r_email < 0.03 THEN NULL
            WHEN r_email < 0.04 THEN lower(fn || '.' || ln || g || 'example.com')   -- missing @
            ELSE lower(fn || '.' || ln || g || '@example.com') END,
       '+44 7700 900' || lpad((g % 1000)::text, 3, '0'),
       CASE WHEN r_dob < 0.005 THEN date '2031-01-01' + (g % 300)                 -- impossible DOB
            ELSE date '1945-01-01' + floor(r_dob * 22000)::int END,
       'QQ' || lpad((g * 7919 % 1000000)::text, 6, '0') || chr(65 + g % 4),
       (g % 200 + 1) || ' ' || street || ' Road',
       city, country,
       CASE WHEN r_seg < 0.70 THEN 'R' WHEN r_seg < 0.88 THEN 'P' ELSE 'S' END,
       timestamp '2018-01-01' + r_created * interval '3000 days'
FROM (
    SELECT g,
           (ARRAY['James','Olivia','Amelia','Noah','Aarav','Priya','Liam','Sofia','Mohammed','Emma',
                  'Lucas','Isla','Arjun','Chloe','Ethan','Ava','Oliver','Mia','Rohan','Grace'])[1 + floor(random()*20)::int] AS fn,
           (ARRAY['Smith','Patel','Jones','Williams','Brown','Khan','Taylor','Davies','Singh','Wilson',
                  'Evans','Murphy','Martin','Garcia','Clarke','Shah','Walker','Hughes','Wright','Green'])[1 + floor(random()*20)::int] AS ln,
           (ARRAY['Oak','Mill','Station','Church','Park','High','Victoria','Kings'])[1 + floor(random()*8)::int] AS street,
           (ARRAY['London','London','Manchester','Leeds','Birmingham','Glasgow','Bristol',
                  'Dublin','Paris','Berlin','Madrid','Mumbai'])[1 + li] AS city,
           (ARRAY['GB','GB','GB','GB','GB','GB','GB','IE','FR','DE','ES','IN'])[1 + li] AS country,
           r_email, r_dob, r_seg, r_created
    FROM (SELECT g, floor(random()*12)::int AS li, random() AS r_email, random() AS r_dob,
                 random() AS r_seg, random() AS r_created
          FROM generate_series(1, 1990) g) d
) s;

-- duplicates: same person onboarded twice by two branches
INSERT INTO crm.customers
SELECT customer_id + 1990, first_name, last_name, email, phone, date_of_birth, national_id,
       address_line, city, country, seg_cd, created_at + interval '400 days'
FROM crm.customers WHERE customer_id <= 10;

INSERT INTO crm.kyc_verifications
SELECT customer_id,
       customer_id,
       (ARRAY['PASSPORT','DRIVING_LICENCE','NATIONAL_ID'])[1 + floor(random()*3)::int],
       'DOC' || lpad((customer_id * 104729 % 100000000)::text, 8, '0'),
       CASE WHEN r < 0.86 THEN 'VERIFIED' WHEN r < 0.94 THEN 'PENDING' WHEN r < 0.98 THEN 'EXPIRED' ELSE 'REJECTED' END,
       random() < 0.02,
       random() < 0.005,
       created_at + interval '2 days'
FROM (SELECT customer_id, created_at, random() AS r FROM crm.customers) c;
