# sync-sqlc-sha256.ps1 — Patch sqlc.yaml sha256 from a built plugin.wasm
#
# WASM sha256 varies by OS/toolchain; CI and local builds must sync after moon build.
# Committed sqlc.yaml files keep sha256: "" — run this before sqlc generate in scripts/CI.
#
# Usage:
#   pwsh scripts/sync-sqlc-sha256.ps1 -WasmPath _build/wasm/debug/build/plugin/plugin.wasm -YamlPath examples/users/sqlc.yaml

param(
  [Parameter(Mandatory = $true)][string]$WasmPath,
  [Parameter(Mandatory = $true)][string]$YamlPath
)

$ErrorActionPreference = "Stop"

$wasm = Resolve-Path -LiteralPath $WasmPath
$yamlFile = Resolve-Path -LiteralPath $YamlPath

if (-not (Test-Path -LiteralPath $wasm)) {
  throw "plugin.wasm not found: $wasm"
}

$sha = (Get-FileHash -LiteralPath $wasm -Algorithm SHA256).Hash.ToLowerInvariant()
$content = Get-Content -LiteralPath $yamlFile -Raw

if ($content -match '(?m)^(\s*sha256:\s*)".*"') {
  $content = [regex]::Replace($content, '(?m)^(\s*sha256:\s*)".*"', "`${1}`"$sha`"", 1)
} elseif ($content -match '(?m)^(\s*sha256:\s*)\S') {
  $content = [regex]::Replace($content, '(?m)^(\s*sha256:\s*)\S+', "`${1}`"$sha`"", 1)
} else {
  throw "No sha256: field in $yamlFile"
}

Set-Content -Path $yamlFile -Value $content -NoNewline -Encoding utf8
Write-Host "sync-sqlc-sha256: $yamlFile -> $sha"
