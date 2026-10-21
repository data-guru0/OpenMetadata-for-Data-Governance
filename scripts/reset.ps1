# Reset the demo between batches.
#   .\scripts\reset.ps1 -Level data       NexaBank databases back to the original synthetic data
#   .\scripts\reset.ps1 -Level metadata   data + delete all NexaBank metadata from OpenMetadata (keeps OM running)
#   .\scripts\reset.ps1 -Level factory    delete EVERYTHING (all containers + volumes; images are kept)
param([ValidateSet("data", "metadata", "factory")][string]$Level = "data")
# no global ErrorActionPreference=Stop: PowerShell 5.1 treats docker's progress output on stderr as an error
Set-Location (Split-Path $PSScriptRoot -Parent)

if ($Level -eq "factory") {
    docker compose down -v --remove-orphans
    Write-Host "Factory reset done. Run .\scripts\start.ps1"
    exit
}
docker compose run --rm tools python cli.py reset-data
if ($Level -eq "metadata") { docker compose run --rm tools python cli.py wipe }
Write-Host "Reset ($Level) done."
