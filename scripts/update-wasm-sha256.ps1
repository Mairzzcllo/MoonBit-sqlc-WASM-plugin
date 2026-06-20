# update-wasm-sha256.ps1 — Write plugin.wasm sha256 into sqlc.yaml files (optional local pin)
#
# Prefer scripts/sync-sqlc-sha256.ps1 in CI/test scripts (called automatically after moon build).
# Use this script when you want to persist sha256 in sqlc.yaml for faster local sqlc runs.
# Usage (from repo root):
#   .\scripts\update-wasm-sha256.ps1              # debug WASM (default build)
#   .\scripts\update-wasm-sha256.ps1 -Release     # release WASM
#   .\scripts\update-wasm-sha256.ps1 -Both        # update debug + release comments in examples

param(
  [switch]$Release = $false,
  [switch]$Both = $false
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

$ROOT = Resolve-Path (Join-Path $PSScriptRoot "..")

function Get-Sha256Hex {
  param([string]$Path)
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return $hash.Hash.ToLowerInvariant()
}

function Set-YamlSha256 {
  param([string]$YamlPath, [string]$Sha256)
  if (-not (Test-Path -LiteralPath $YamlPath)) {
    Write-Warning "Skip missing: $YamlPath"
    return
  }
  $yaml = Get-Content -LiteralPath $YamlPath -Raw
  if ($yaml -match '(?m)^(\s*sha256:\s*)".*"') {
    $yaml = [regex]::Replace($yaml, '(?m)^(\s*sha256:\s*)".*"', "`${1}`"$Sha256`"", 1)
  } else {
    Write-Warning "No sha256: field in $YamlPath"
    return
  }
  Set-Content -Path $YamlPath -Value $yaml -NoNewline -Encoding utf8
  Write-Host "  updated sha256 in $YamlPath"
}

function Ensure-Build {
  param([string[]]$BuildArgs, [string]$WasmPath)
  if (-not (Test-Path -LiteralPath $WasmPath)) {
    Write-Host "==> moon $($BuildArgs -join ' ')"
    Push-Location $ROOT
    try {
      & moon @BuildArgs
      if ($LASTEXITCODE -ne 0) { throw "moon build failed (exit $LASTEXITCODE)" }
    } finally {
      Pop-Location
    }
  }
  if (-not (Test-Path -LiteralPath $WasmPath)) {
    throw "WASM not found: $WasmPath"
  }
}

$targets = @()
if ($Both) {
  $targets = @(
    @{ Release = $false; Wasm = Join-Path $ROOT "_build\wasm\debug\build\plugin\plugin.wasm"; Args = @("build", "--target", "wasm") },
    @{ Release = $true; Wasm = Join-Path $ROOT "_build\wasm\release\build\plugin\plugin.wasm"; Args = @("build", "--target", "wasm", "--release") }
  )
} elseif ($Release) {
  $targets = @(@{ Release = $true; Wasm = Join-Path $ROOT "_build\wasm\release\build\plugin\plugin.wasm"; Args = @("build", "--target", "wasm", "--release") })
} else {
  $targets = @(@{ Release = $false; Wasm = Join-Path $ROOT "_build\wasm\debug\build\plugin\plugin.wasm"; Args = @("build", "--target", "wasm") })
}

Write-Host "MoonBit sqlc WASM — update sha256 in sqlc.yaml" -ForegroundColor Cyan

foreach ($t in $targets) {
  Ensure-Build -BuildArgs $t.Args -WasmPath $t.Wasm
  $sha = Get-Sha256Hex -Path $t.Wasm
  $label = if ($t.Release) { "release" } else { "debug" }
  Write-Host "`n$label plugin.wasm sha256=$sha"

  if ($Both -or (-not $Release -and -not $t.Release) -or ($Release -and $t.Release)) {
    Set-YamlSha256 -YamlPath (Join-Path $ROOT "examples\users\sqlc.yaml") -Sha256 $sha
    if (-not $Both) {
      Set-YamlSha256 -YamlPath (Join-Path $ROOT "sqlc.yaml") -Sha256 $sha
    }
  }
}

Write-Host "`n[OK] sha256 updated. Re-run sqlc generate to verify (no sha256 warning)." -ForegroundColor Green
