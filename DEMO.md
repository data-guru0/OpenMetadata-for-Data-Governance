# DEMO.md

Setup is in [README.md](README.md).

---

### Browser tabs to keep open

| Tab | URL | Role in class |
|---|---|---|
| **Adminer** | <http://localhost:8081> | "life before governance": a raw database browser |
| **OpenMetadata** | <http://localhost:8585> | where you build governance (login `admin@open-metadata.org` / `admin`) |


### The NexaBank cast (people you will create in OpenMetadata)

| Person | Login (password `NexaBank@2026`) | Team | Role in the story |
|---|---|---|---|
| Priya Sharma | `priya.sharma@nexabank.example` | Data Platform | Data Steward: looks after data definitions and quality |
| Maria Lopez | `maria.lopez@nexabank.example` | Customer Data | Data Owner for customer data (CRM, KYC) |
| David Chen | `david.chen@nexabank.example` | Risk Analytics | Fraud analyst: uses the data for the fraud model |

---

# PART 0: Life WITHOUT Data Governance


## Tour the raw databases in Adminer


🖱️ **Do it.** Open <http://localhost:8081>. Log in three times (use *Logout* in between):

| System | Server | Username | Password | Database |
|---|---|---|---|---|
| PostgreSQL | `nexabank-customers-db` | `crm_admin` | `crm_admin_pw` | `customers_db` |
| PostgreSQL | `nexabank-transactions-db` | `payments_admin` | `payments_admin_pw` | `transactions_db` |
| PostgreSQL | `nexabank-analytics-db` | `analytics_admin` | `analytics_admin_pw` | `analytics_db` |


---

# PART 1: OpenMetadata 

## 1.1 OpenMetdata Walkthrough

🖱️ **Do it.** Log in to <http://localhost:8585> as `admin@open-metadata.org` / `admin`. Click **Explore** in the left menu.

✅ **Expected:** an empty catalog. *"OpenMetadata knows nothing until we connect it to our systems."*


| Menu | What lives there |
|---|---|
| **Explore** | search and browse every data asset |
| **Lineage** | the lineage explorer |
| **Observability** | Data Quality, Incident Manager, Alerts, Test Library |
| **Insights** | catalogue KPIs (ownership / description / tier coverage) |
| **Data Marketplace** | Domains, Data Products |
| **Govern** | Glossary, Classification, Metrics, Workflows |
| **Context Center** | articles and documents |
| **Settings** (bottom) | Services, Team & User Management, Access Control, Applications |

---

## 1.2 Services and connectors: register the three databases


🖱️ **Do it: service #1 (Customer DB).**

1. **Settings** (left menu, bottom) → **Services** tile → **Databases** → **Add New Service**.
2. Step **Select Service Type**: in the connector search box type `Postgres` → click the **Postgres** tile.
3. Step **Connect**:
   * **Name this service → Service Name** → `nexabank_customers`  ⚠️ exact name; the scripts in `scripts/` look for it.
   * Click **+ Add a description** → `NexaBank CRM: customer master data and KYC verifications. Owned by Customer Data team.`
   * Section **1 Connection**: *Username* → `om_reader` · *Host and Port* → `nexabank-customers-db:5432`
     (container name, *internal* port) · *Database* → `customers_db`
   * Section **2 Authentication**: *Auth Configuration Type* **Basic Auth** (already selected) → *Password* → `om_reader_pw`
   * Click **Test Connection** (bottom). A **Connection status** window opens; wait ~20 s.
4. Click **Done**, then **Next: What to Ingest**.
5. Step **What to Ingest** ("What should we ingest?"): open the **Schemas** card. Under *Always exclude* you already see
   `is exactly information_schema`. In the rule box below it leave the condition **starts with**, type `public`, click
   **+ Add**. The card now says **Excluding 2 rules**.
6. Click **Create & Deploy**.

* Note the header: **Owners = admin**. Whoever registers a system becomes its owner by default

🖱️ **Repeat for the other two services** (same steps, same `om_reader` / `om_reader_pw`, same `public` exclude rule):

| Service Name | Host and Port | Database | Description |
|---|---|---|---|
| `nexabank_transactions` | `nexabank-transactions-db:5432` | `transactions_db` | `NexaBank core payments: accounts and card/online transactions.` |
| `nexabank_analytics` | `nexabank-analytics-db:5432` | `analytics_db` | `NexaBank analytics warehouse: staging, risk marts and reports.` |

For `nexabank_analytics`, **Test Connection** shows **Connection verified · 9 of 9 checks passed** (the query log exists).

⚙️ **Behind the scenes.** OpenMetadata stored the connection (password encrypted) and the **AutoPilot**
application created a set of **agents** (scheduled ingestion jobs) for the service and started the first ones on the
ingestion runner (Airflow, <http://localhost:8082>)..

---

## 1.3 Metadata ingestion and agents

🖱️ **Do it.** **Settings → Services → Databases → `nexabank_analytics`** → open the **Agents** tab.
.

Show the same jobs in Airflow (<http://localhost:8082>, `admin`/`admin`): each agent is a DAG. *"OpenMetadata is the
brain, the ingestion runner is the muscle."*

---

## 1.4 Data catalog and discovery: databases → schemas → tables → columns

🖱️ **Do it.**

1. **Explore** → **Tables**. All 10 tables/views from 3 databases in one list.
2. Search box: type `card`. Results include `payments.transactions`, `staging.stg_transactions` and
   `marts.fraud_training_features`, all of which have a `card_number` column. *One search across three databases.*
3. Use the left filters: **Service** = `nexabank_analytics`, then **Schema** = `marts`.
4. Breadcrumb at the top: click `payments` (schema) → `transactions_db` (database) → `nexabank_transactions` (service).
5. Open **`analytics_db.reports.risk_report`**: a **View**. Open the **View Definition** tab to show the SQL.

---

## 1.5 Data owners and teams

🖱️ **Do it: create three teams first.** **Settings → Team & User Management → Teams** (you land on *Organization*) →
**+ Add**. In the **Add Team** dialog fill *Name* and *Display Name*, keep *Team Type* = **Group**, click **Save**. ×3:

| Name | Display Name |
|---|---|
| `Data_Platform` | `Data Platform` |
| `Customer_Data` | `Customer Data` |
| `Risk_Analytics` | `Risk Analytics` |

🖱️ **Do it: create three users.** **Settings → Team & User Management → Users → Add User**. Fill *Email* and
*Display Name*, choose **Create Password** (not *Automatically Generate*) and type `NexaBank@2026` twice, pick the
team in *Teams*, click **Create**. ×3:

| Email | Display Name | Teams |
|---|---|---|
| `priya.sharma@nexabank.example` | `Priya Sharma` | Data Platform |
| `maria.lopez@nexabank.example` | `Maria Lopez` | Customer Data |
| `david.chen@nexabank.example` | `David Chen` | Risk Analytics |

🖱️ **Do it: assign owners.** Open each table → in the header click the pencil next to **Owners** → the popover opens on
the **Teams** tab → click the team → **Update** (if the button is shown; otherwise it saves on click).


| Asset | Owner |
|---|---|
| `crm.customers`, `crm.kyc_verifications` | `Customer Data` |
| `payments.transactions`, `payments.accounts` | `Data Platform` |
| `staging.stg_customers`, `staging.stg_transactions` | `Data Platform` |
| `marts.customer_risk_scores`, `marts.fraud_training_features`, `reports.risk_report`, `reports.daily_fraud_kpis` | `Risk Analytics` |


✅ **Verify.** **Explore → Tables** → filter **Owners** = `Risk Analytics` → 4 assets.


---

## 1.6 Data documentation and descriptions

📘 **Theory.** Descriptions turn technical names into shared meaning. In OpenMetadata they are rich text, versioned,
and (for tables) searchable.


🖱️ **Do it.** Open `crm.customers`:

1. **Columns** tab → box **Description** → pencil → dialog *Edit Description for customers* → type → **Save**:
   `Master record of every NexaBank customer. One row per customer. Contains direct PII. Source of truth: CRM onboarding.`
2. Same tab, column grid → hover the **Description** cell of row `seg_cd` → pencil → **Save**:
   `Customer segment code: R = Retail, P = Premier (high-net-worth), S = SME (small business).`
3. Open `marts.fraud_training_features` → table description:
   `One row per card/online transaction with model-ready features. Used to train the fraud-detection model.`

✅ **Verify.** Search box at the top → `onboarding` → `crm.customers` is found **through its description**.

---

## 1.7 Business glossary and glossary terms (with an approval workflow)

📘 **Theory.** A **glossary** defines *business* concepts once ("Customer Segment", "Fraud Label"), independent of
any table. **Terms** are then linked to the many columns that implement them.
🖱️ **Do it: create the glossary.** **Govern → Glossary → Add Glossary**:

* *Name* → `NexaBank_Banking_Glossary`, *Display Name* → `NexaBank Banking Glossary`
* *Description* → `Official business vocabulary of NexaBank. Terms are approved by the Data Steward.`
* *Reviewers* → **+** → in the popover open the **Users** tab → `Priya Sharma` → **Update**
* *Owners* → **+** → **Teams** tab → `Data Platform` → **Update**
* **Save**

🖱️ **Do it: add terms.** Inside the glossary → **Add term** → *Name*, *Display Name*, *Description*, *Synonyms*
(type each synonym and press Enter) → **Save** (repeat):

| Name / Display Name | Description | Synonyms |
|---|---|---|
| `Customer_Segment` / `Customer Segment` | `Commercial grouping of a customer: Retail (R), Premier (P), SME (S).` | `segment, seg_cd` |
| `KYC_Status` / `KYC Status` | `Outcome of Know-Your-Customer identity verification: VERIFIED, PENDING, EXPIRED, REJECTED.` | `kyc` |
| `Fraud_Label` / `Fraud Label` | `True when the transaction was confirmed fraudulent through a chargeback investigation.` | `is_fraud` |
| `Primary_Account_Number` / `Primary Account Number (PAN)` | `The 16-digit card number. PCI DSS scope: must never leave the payments zone unmasked.` | `card number, PAN` |
| `Customer_Risk_Tier` / `Customer Risk Tier` | `LOW / MEDIUM / HIGH band derived from KYC, PEP, sanctions and foreign activity.` | `risk tier` |


✅ **Verify the workflow**
1. The terms show status **In Review**.
2. Open a **private/incognito** browser window → <http://localhost:8585> → log in as `priya.sharma@nexabank.example` / `NexaBank@2026`.
3. As Priya: **Govern → Glossary → NexaBank Banking Glossary**. The *Status* column now shows an **Approve** button
   for every term, because she is the reviewer. Click **Approve** on each.
4. Back as admin (refresh): every term is **Approved**. The approvals are tasks in the glossary's
   **Activity Feeds & Tasks** tab: who approved, when.

🖱️ **Do it: link terms to columns.** Open each table → **Columns** tab → in the column's **Glossary Terms** cell click
**+ Add** → type part of the term → tick it → **Update**:

| Column | Term |
|---|---|
| `crm.customers.seg_cd`, `staging.stg_customers.seg_cd` | Customer Segment |
| `crm.kyc_verifications.status`, `staging.stg_customers.kyc_status` | KYC Status |
| `payments.transactions.is_fraud`, `marts.fraud_training_features.is_fraud` | Fraud Label |
| `payments.transactions.card_number` and `card_number` in `stg_transactions` and `fraud_training_features` | Primary Account Number (PAN) |
| `marts.customer_risk_scores.risk_tier`, `marts.fraud_training_features.customer_risk_tier` | Customer Risk Tier |

✅ **Verify.** Open the term **Primary Account Number (PAN)** → **Assets** tab shows **6**: the three `card_number`
columns and their three tables, in two databases.
*"The business concept now knows every physical place it lives."* Q3 answered.


---

## 1.8 Tags, classifications and tiers

📘 **Theory.** A **Classification** is a family of **tags** (e.g. `PII` → `Sensitive`, `NonSensitive`).
OpenMetadata ships `PII`, `Tier` (Tier1 = most critical … Tier5) and others; you can create your own.


🖱️ **Do it: create a custom classification.** **Govern → Classification**. The left list shows the built-in
classifications (Certification, KnowledgeCenter, PersonalData, PII, Tier). Click **+ Add Classification**; a drawer
*Adding New Classification* opens:

* *Name* → `DataSensitivity` · *Description* (required) → `NexaBank information-security classes.` ·
  *Mutually Exclusive* → **on** → **Save**

Then **Add Tag** four times (*Name* + *Description*, **Save**):

| Name | Description |
|---|---|
| `Public` | `Data that can be shared outside NexaBank without any harm. Example: published branch locations, product interest rates, public reports. No access restrictions.` |
| `Internal` | `Data for NexaBank employees only, not for the public. Disclosure would cause little harm. Example: aggregated reports such as reports.risk_report, internal KPIs. Accessible to all staff; do not share externally.` |
| `Confidential` | `Business-sensitive data for people who need it for their job. Disclosure could harm NexaBank or its customers. Example: customer risk scores, fraud model features (marts.customer_risk_scores, marts.fraud_training_features). Access only for the owning team and approved roles.` |
| `Restricted` | `Most sensitive data: direct personal identifiers, card data, national IDs, credentials. Subject to GDPR and PCI DSS. Example: crm.customers, crm.kyc_verifications, payments.transactions (card numbers). Strictly need-to-know access; must be masked or excluded before use in analytics or ML.` |

The levels go from least to most sensitive. Because the classification is **Mutually Exclusive**, a table can carry
only **one** of them.

🖱️ **Do it: apply Tiers and sensitivity.** On each table: header → pencil next to **Tier** → pick (the popover lists
*Tier1 … Tier5* with explanations). Right-hand panel → **Tags** → pencil/+ → add the DataSensitivity tag.

| Table | Tier | DataSensitivity |
|---|---|---|
| `crm.customers` | **Tier1** | Restricted |
| `crm.kyc_verifications` | Tier1 | Restricted |
| `payments.transactions` | **Tier1** | Restricted |
| `marts.fraud_training_features` | **Tier1** | Confidential |
| `marts.customer_risk_scores` | Tier2 | Confidential |
| `reports.risk_report` | Tier2 | Internal |

✅ **Verify.** **Explore** → filter **Tier** = Tier1 → 4 tables.


---

## 1.9 Sensitive data / PII classification

📘 **Theory.** Finding PII by hand does not scale. The **Auto Classification** agent samples column values and
names, runs recognisers (emails, card numbers, IBANs, names…) and **suggests** `PII.Sensitive` / `PII.NonSensitive`
tags. A human confirms.

🖱️ **Do it.** **Settings → Services → Databases → `nexabank_customers` → Agents** tab → on the **AutoClassification
Agent** card click **Run**. Repeat for `nexabank_transactions` and `nexabank_analytics`. ~1 minute each.

✅ **Expected (verified on this dataset):**

| Table | Suggested `PII.Sensitive` | Suggested `PII.NonSensitive` |
|---|---|---|
| `crm.customers` | `first_name`, `last_name`, `email` | `date_of_birth`, `city`, `created_at` |
| `payments.accounts` | `iban` | `opened_at` |
| `payments.transactions` | **`card_number`** | `txn_ts` |
| `staging.stg_transactions` | **`card_number`** | `txn_ts` |
| `marts.fraud_training_features` | **`card_number`** | `txn_ts` |

Refresh a table's **Columns** tab: the tags appear as chips **Sensitive** / **NonSensitive** with a small *automation*
icon. That icon (state *Suggested*) means a bot applied it, not a person. 

**Discuss what the machine missed:** `phone` and `national_id` in `crm.customers` were **not** detected (synthetic
phone numbers come from a reserved fictional range; the NI-number format is unusual). Tag both manually:
column → **Tags** → `PII.Sensitive`. *Automation finds most of it; stewards are still accountable for all of it.*

---

## 1.10 Data profiling

📘 **Theory.** A **profile** is statistics about the *content*: row count, null %, distinct count, min/max/mean
per column, tracked over time. It is how you notice "amount should never be negative" without reading 45,000 rows.

🖱️ **Do it.** **Settings → Services → Databases → `nexabank_transactions` → Agents** → **Profiler Agent** card → **Run**.
Repeat for `nexabank_customers` and `nexabank_analytics`. ~1-2 minutes each.

⚙️ **Behind the scenes (worth showing!)** AutoPilot configured the Profiler agent with a classification filter
**include `Tier1`, `Tier2`**: *it only profiles tables you declared critical.* That's why we set Tiers first.
Untiered tables (e.g. `payments.accounts`, `staging.*`) are skipped: click **Logs** on the agent card and look for
*Filtered*. Profiling costs compute; governance decides where to spend it.

✅ **Expected:** open `payments.transactions` → **Data Observability** → **Table Profile** / **Column Profile**:

| Column | What students should spot |
|---|---|
| `amount` | **min = -362.87** (should never be negative), max 1,207.24, mean 24.62 |
| `currency` | **3 distinct values** (expected 2: GBP, EUR) → the third is `XXX` |
| `merchant_category` | **436 nulls** |
| `txn_ts` | 45,000 distinct timestamps for 45,045 rows → **duplicates?** |
| `card_number` | 4,618 nulls = ATM withdrawals (no card number), fine |

Also open `crm.customers` → Column Profile: `email` has **57 nulls**.

🏛️ **Governance significance:** profiling turns "data quality" from opinion into numbers, per run, with history.

---

## 1.11 Data quality tests

📘 **Theory.** A **test case** is an executable expectation ("amount between 0 and 10,000"). Tests run on a schedule;
each run stores a result. A failure opens an **incident** that someone must resolve.



🖱️ **Do it.** Open `payments.transactions` → **Data Observability** → **Data Quality** → **Add** → **Test case**:

| Test level / column | Test type | Parameters | Test name |
|---|---|---|---|
| Column `amount` | **Column Values To Be Between** | Min `0`, Max `10000` | `transactions_amount_valid_range` |
| Column `currency` | **Column Values To Be In Set** | Allowed values `GBP`, `EUR`; **Match enum: on** | `transactions_currency_iso` |
| Table | **Custom SQL Query** | SQL: `SELECT account_id, txn_ts, amount FROM payments.transactions GROUP BY account_id, txn_ts, amount HAVING count(*) > 1` · Strategy `ROWS` · Threshold `0` | `transactions_no_duplicate_postings` |


Run them: table → **Data Observability** → **Data Quality** → inner tab **Pipelines** → **Run**.
Results appear under the inner tab **Test Cases** with counters *Total Tests / Successful Tests / Failed Tests*.

✅ **Expected results (baseline data):**

| Test | Status | Result message |
|---|---|---|
| `transactions_amount_valid_range` | ❌ Failed | `Found min=-362.87, max=1207.24 vs. the expected min=0.0, max=10000.0` |
| `transactions_currency_iso` | ❌ Failed | `Found countInSet=44939` (of 45,045) |
| `transactions_no_duplicate_postings` | ❌ Failed | `Found 45 row(s). Test query is expected to return <= 0 row(s).` |
| `features_amount_valid_range` | ❌ Failed | negative amounts propagated downstream |

Then: **Observability → Incident Manager** (or the table's **Incidents** sub-tab). Each failure opened an
**incident** automatically. Assign the transactions incidents to **Data Platform** (the owner!) and add a comment.


---

## 1.12 Data lineage (table-level and column-level)

📘 **Theory.** **Lineage** is the graph of *where data comes from and where it goes*. OpenMetadata builds it from
several sources.

**Open customer_risk_scores table**

**Discuss Lineage and UpStream and Downstream**

(Optional) The hop from the CRM/Payments databases into `staging` is done by a Python ETL that no connector can see, so
it is missing from the graph. To add it, run once in PowerShell: `.\scripts\register-lineage.ps1`. It declares those
4 edges (with column mappings) through the OpenMetadata API; refresh the Lineage tab to see `crm.*` and `payments.*`
on the left.

---

## 1.13 Upstream/downstream dependencies and impact analysis

📘 **Theory.** **Upstream** = what an asset depends on. **Downstream** = what depends on it. **Impact analysis**
= "if I change X, what breaks, and whom must I warn?"

---

## 1.14 Data domains and data products

```
Domain: Retail Banking  (owner: Data Platform)                     ← the business area
 ├── all 10 tables: crm.*, payments.*, staging.*, marts.*, reports.*
 │
 └── Data Product: Fraud Detection Data  (owner: Risk Analytics)   ← official package inside it
       ├── marts.fraud_training_features
       ├── marts.customer_risk_scores
       └── reports.daily_fraud_kpis
```

😖 **Without it:** a new data scientist asks *"which data should I use for fraud work?"*. They search 10 tables, maybe
pick `staging.stg_transactions` (raw, with card numbers) and ask around on chat. With a data product they open
**Fraud Detection Data** and find the 3 approved tables, the owner and the rules.

### Step 1: create the domain

🖱️ **Data Marketplace → Domains → Add Domain**:

| Field | Value |
|---|---|
| Name | `Retail_Banking` |
| Display Name | `Retail Banking` |
| Description (required) | `Retail customers, their payments and the risk analytics built on them.` |
| Domain Type (required) | `Consumer-aligned` |
| Owners | `Data Platform` |

→ **Save**.

*Domain Type* (don't overthink it; pick **Consumer-aligned** for the demo):

| Type | Meaning | Example |
|---|---|---|
| Source-aligned | data produced by an operational system | the raw payments system data |
| **Consumer-aligned** | data shaped for a business purpose or team | Retail Banking analytics ← **we choose this** |
| Aggregate | data combined from several domains | a bank-wide "customer 360" view |

### Step 2: put the tables in the domain

🖱️ Open the domain **Retail Banking** → **Assets** tab → add all 10 NexaBank tables/views
(`crm.customers`, `crm.kyc_verifications`, `payments.accounts`, `payments.transactions`, `staging.stg_customers`,
`staging.stg_transactions`, `marts.customer_risk_scores`, `marts.fraud_training_features`, `reports.risk_report`,
`reports.daily_fraud_kpis`).

### Step 3: create the data product

🖱️ **Data Marketplace → Data Products** (or the domain's *Data Products* tab) → **Add Data Product**:

| Field | Value |
|---|---|
| Name | `Fraud_Detection_Data` |
| Display Name | `Fraud Detection Data` |
| Description | `Governed, quality-tested data for fraud model training and fraud KPIs. Card numbers must not be used for modelling.` |
| Domain | `Retail Banking` (if asked) |
| Owners | `Risk Analytics` |

→ **Save**. Then open the data product → **Assets** → add only these 3:
`marts.fraud_training_features`, `marts.customer_risk_scores`, `reports.daily_fraud_kpis`.

### Step 4: verify

✅ **Explore** → left filter **Domain = Retail Banking** → the NexaBank tables appear. Open any table: the header shows
**Domains: Retail Banking**. Open the data product **Fraud Detection Data**: exactly 3 assets, owner Risk Analytics.


---

## 1.15 Governance policies and access control

📘 **Theory.** OpenMetadata has **policies** (rules: *resource + operations + condition + allow/deny*) bundled into
**roles**, assigned to users or teams. Conditions can use metadata, e.g. `matchAnyTag('PII.Sensitive')`.

⚠️ **Note** these policies control what users can do **inside OpenMetadata** (see sample data,
profiles and queries, edit tags…). They do **not** change permissions inside PostgreSQL. A user with a database
password can still `SELECT` everything. Database security is enforced in the database (GRANTs, row-level security,
masking) or by tools like Vault/OPA covered earlier in the course. OpenMetadata tells you **where** to enforce.

🖱️ **Do it: create the policy.** **Settings → Access Control → Policies → Add Policy**:

* *Name* → `Deny_PII_Data_Access`, *Description* → `Analysts cannot view sample rows, profiles or queries of PII tables.`
* **Add Rule**: *Rule Name* `deny-pii-sample-data` · *Resources* `Table` ·
  *Operations* `ViewSampleData`, `ViewQueries`, `ViewDataProfile` · *Condition* `matchAnyTag('PII.Sensitive')` · *Effect* **Deny**

🖱️ **Do it: role and assignment.** **Settings → Access Control → Roles → Add Role**: *Name* `PII_Restricted_Analyst`,
*Policies* `Deny_PII_Data_Access`. Then **Settings → Team & User Management → Users → David Chen → Roles** → add
`PII_Restricted_Analyst`.

✅ **Verify (incognito window as David).** Log in as `david.chen@nexabank.example` / `NexaBank@2026` and open the
**Data Observability** tab of two tables (verified on a fresh install):

| Asset | Data Observability (profile) |
|---|---|
| `crm.customers` (table tagged `PII.Sensitive`) | **"You don't have necessary permissions. Please check with the admin…"** |
| `marts.customer_risk_scores` (no PII tag) | full Table Profile: 2,000 rows, 9 columns |

---

## 1.16 Usage, activity, collaboration and governance workflows

📘 **Theory.** Governance is a social process. OpenMetadata records **who uses what** (usage), **what changed**
(activity), and supports **conversations, tasks and announcements** on any asset.

🖱️ **Do it.**

1. **Usage:** the table header shows **Usage** (a percentile) and the **Queries** tab; both are fed by the *Usage Agent*,
   which reads the analytics database's query log. Right after the first install they can be **0**; once the agent
   has run again on the ETL's query history (verified a day later) `marts.fraud_training_features` showed **Usage
   33rd pctile** and **Queries 3**. *"Popular tables are the ones people depend on; treat them with extra care."*
   (Tables in the CRM and Payments databases stay at 0: those databases have no query log.)
2. **Conversation:** on `marts.fraud_training_features` → **Activity Feeds & Tasks** → start a conversation:
   `@Maria Lopez why does this table contain card_number? Can we drop it?` (the @mention notifies her).
3. **Task:** on `crm.customers.address_line` → *Request description* → assign to `Customer Data`.
   Log in as Maria (incognito) → her task list → write the description → resolve.
4. **Follow:** as admin, click **Follow** on `payments.transactions`: you'll get notified of schema changes.

---

## 1.17 Ingestion scheduling, refresh and change detection

📘 **Theory.** Metadata goes stale unless agents re-run. Each agent has a **schedule** (cron). Re-ingestion detects
schema changes and records them as new entity **versions**.

🖱️ **Do it: look at schedules.** **Settings → Services → Databases → `nexabank_transactions` → Agents**. Each card shows
its schedule in words: Metadata *At 12:00 AM, Only on sunday*, Lineage and Usage *At 02:00 AM, Only on sunday*,
Profiler and AutoClassification *At 04:00 AM, Only on sunday*, plus **Recent runs** and **View run history**.
On the Metadata Agent card open **⋮** → **Edit configuration** → go to the schedule step → choose **Daily** → save.
(The same ⋮ menu has **Pause**, **Re-deploy** and **Delete agent**.)

🖱️ **Do it: make a schema change happen.** In **Adminer** (`transactions_db` as `payments_admin`) → *SQL command*:

```sql
ALTER TABLE payments.transactions ADD COLUMN merchant_mcc char(4);
```

Back in OpenMetadata: **Agents** tab → **Metadata Agent** card → **Run**. Wait ~1 min.

✅ **Expected (verified):** `payments.transactions` now shows **Columns 12**; the version number at the top-right went
up; click it (**Version history**) → the latest version shows **`merchant_mcc` added** by **ingestion-bot**. Your owner,
Tier, tags and tests were **kept**.

(Clean-up, optional: `ALTER TABLE payments.transactions DROP COLUMN merchant_mcc;` and run the agent again.)


---
