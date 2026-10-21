# NexaBank Data Governance with OpenMetadata

---

## Prerequisites

| Need | Value |
|---|---|
| Docker Desktop | running, with **≥ 8 GB RAM** and **4 CPUs** allocated (the stack uses ~5.5 GB) |
| Disk | ~15 GB free (OpenMetadata ingestion image alone is ~8 GB) |
| Free ports | 8585, 8586, 8082, 8081, 5433, 5434, 5435 |
| Browser | any modern browser |

No local Python or database tools needed: everything runs in containers.

---

## Services, URLs and credentials (local demo only)

| Service | URL / host | Credentials |
|---|---|---|
| **OpenMetadata UI** | <http://localhost:8585> | `admin@open-metadata.org` / `admin` |
| **Adminer** (plain DB browser, "before governance") | <http://localhost:8081> | see DB rows below |
| Airflow (runs OpenMetadata agents) | <http://localhost:8082> | `admin` / `admin` |
| customers_db | `nexabank-customers-db:5432` (inside Docker), `localhost:5433` (host) | `crm_admin` / `crm_admin_pw` |
| transactions_db | `nexabank-transactions-db:5432`, `localhost:5434` | `payments_admin` / `payments_admin_pw` |
| analytics_db | `nexabank-analytics-db:5432`, `localhost:5435` | `analytics_admin` / `analytics_admin_pw` |
| Read-only user for OpenMetadata (all 3 DBs) | n/a | `om_reader` / `om_reader_pw` |

---

## 5. Start

```powershell
git clone https://github.com/data-guru0/OpenMetadata-for-Data-Governance.git
cd OpenMetadata-for-Data-Governance
.\scripts\start.ps1
```

If PowerShell says *"running scripts is disabled on this system"*, run this once and retry:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (or run `powershell -ExecutionPolicy Bypass -File .\scripts\start.ps1`).

Or on any OS: `docker compose up -d --build`, then wait until <http://localhost:8585> shows the login page.

First start: 5-15 minutes (image pulls ~12 GB, then OpenMetadata migrations). Later starts: ~2 minutes.

What happens automatically:

1. The three PostgreSQL databases are created and seeded (`databases/*`).
2. The `om_reader` read-only user is created in each, with `pg_read_all_stats` in analytics_db for query-log lineage.
3. OpenMetadata migrates its metadata store and starts (empty catalog).
4. The one-shot `tools` container copies CRM and Payments data into `analytics_db` (staging + marts), then exits.

Health check: `start.ps1` ends with *OpenMetadata 2.0.5 is up*, the tools output (*built marts.fraud_training_features:
INSERT 0 45045*) and the URLs; <http://localhost:8585> shows the login page. The `nexabank-tools` container shows as
*Exited (0)*: that is expected, it only runs once.

## 6. Stop

```powershell
docker compose stop          # keeps all data and metadata
docker compose start         # resume later
```

After a PC or Docker Desktop restart, run `docker compose up -d` in this folder once. It makes sure every
container is running (if Elasticsearch is down, search and the glossary **Assets** tab show 0 results).

## 7. Reset between batches

| Goal | Script |
|---|---|
| Restore the original synthetic data in the 3 databases | `.\scripts\reset.ps1 -Level data` |
| Also remove everything DEMO.md creates in OpenMetadata | `.\scripts\reset.ps1 -Level metadata` |
| Everything from zero (containers + volumes; images are kept) | `.\scripts\reset.ps1 -Level factory`, then `.\scripts\start.ps1` |

Optional helper for DEMO.md 1.12: `.\scripts\register-lineage.ps1` declares the cross-database ETL lineage
(CRM/Payments → staging) in OpenMetadata.
