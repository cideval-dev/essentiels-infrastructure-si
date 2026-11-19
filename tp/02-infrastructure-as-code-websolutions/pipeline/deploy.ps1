param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$RootDir  = Split-Path -Parent $PSScriptRoot
$AppDir   = Join-Path $RootDir "app"
$InfraDir = Join-Path $RootDir "infra"
$ImageTag = "websolutions-api:$Version"

if (-not $env:TF_VAR_db_password) {
    $env:TF_VAR_db_password = "WsLocalSecret2026!"
}

Write-Host "=== [1/4] Construction de l'artefact $ImageTag ===" -ForegroundColor Cyan
docker build -t $ImageTag $AppDir
if ($LASTEXITCODE -ne 0) { throw "Echec du build Docker pour $ImageTag" }

Write-Host "=== [2/4] Execution des tests automatises sur $ImageTag ===" -ForegroundColor Cyan
docker run --rm $ImageTag npm test
if ($LASTEXITCODE -ne 0) {
    Write-Host "BLOCAGE PIPELINE : Les tests ont echoue. Aucun deploiement effectue." -ForegroundColor Red
    exit 1
}

Write-Host "=== [3/4] Deploiement sur la cible de test via OpenTofu (version $Version) ===" -ForegroundColor Cyan
Push-Location $InfraDir
try {
    tofu apply -auto-approve -var="app_version=$Version"
    if ($LASTEXITCODE -ne 0) { throw "Echec du deploiement OpenTofu" }
}
finally {
    Pop-Location
}

# Recharger Nginx pour actualiser la resolution DNS interne vers le nouveau conteneur API
docker exec websolutions-web nginx -s reload | Out-Null

Write-Host "=== [4/4] Controle HTTP de sante (/health) ===" -ForegroundColor Cyan
Start-Sleep -Seconds 2
$Health = Invoke-RestMethod -Uri "http://127.0.0.1:8080/health" -Method Get
if ($Health.status -ne "ok" -or $Health.version -ne $Version) {
    throw "Echec du controle de sante : reponse inattendue ($($Health | ConvertTo-Json -Compress))"
}

Write-Host "SUCCES : Version $Version deployee et validee ($($Health | ConvertTo-Json -Compress))" -ForegroundColor Green