# Start the whole NexaBank governance stack and wait until it is usable.
# no global ErrorActionPreference=Stop: PowerShell 5.1 treats docker's progress output on stderr as an error
Set-Location (Split-Path $PSScriptRoot -Parent)

docker compose up -d --build
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

Write-Host "`nWaiting for OpenMetadata (first start runs DB migrations: 3-6 minutes)..." -NoNewline
$deadline = (Get-Date).AddMinutes(12)
while ((Get-Date) -lt $deadline) {
    try { $v = Invoke-RestMethod http://localhost:8585/api/v1/system/version -TimeoutSec 3 -ErrorAction Stop; break } catch { Start-Sleep 5; Write-Host "." -NoNewline }
}
if (-not $v) { throw "OpenMetadata did not come up. Check: docker compose logs openmetadata-server" }
Write-Host " OpenMetadata $($v.version) is up."
Write-Host "Sample data (tools container):"
docker compose logs --no-log-prefix tools | Select-Object -Last 4

Write-Host @"

  OpenMetadata UI     http://localhost:8585   admin@open-metadata.org / admin
  Adminer (DB UI)     http://localhost:8081
  Airflow (agents)    http://localhost:8082   admin / admin

  Next: open DEMO.md
"@
