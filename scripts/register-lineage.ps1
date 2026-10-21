# DEMO.md 1.12 (optional): declare the cross-database ETL hops (CRM/Payments -> staging) as lineage in OpenMetadata.
# Run it after the three services have been created and ingested.
Set-Location (Split-Path $PSScriptRoot -Parent)
docker compose run --rm tools python cli.py lineage
