# setup-mooncakes.ps1 — Windows: verify mooncakes runtime install (wasm-gc only)
#
# Usage (from repo root):
#   .\scripts\setup-mooncakes.ps1
#   .\scripts\setup-mooncakes.ps1 -Version 0.1.1

param(
  [string]$Version = "0.1.3",
  [string]$Package = "Mairzzcllo/moonbit_sqlc_plugin"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

$ROOT = Resolve-Path (Join-Path $PSScriptRoot "..")
$SMOKE = Join-Path $env:TEMP "moonbit_sqlc_mooncakes_smoke"

function Write-Step([string]$Msg) { Write-Host "`n==> $Msg" -ForegroundColor Cyan }

function Write-JsonNoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "MoonBit sqlc — mooncakes setup (Windows)" -ForegroundColor Cyan
Write-Host "Package: $Package@$Version"

if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  throw "moon not found. Install: https://www.moonbitlang.com/download/"
}

Write-Step "MoonBit toolchain"
& moon --version

$cred = Join-Path $env:USERPROFILE ".moon\credentials.json"
if (Test-Path $cred) {
  Write-Host "mooncakes credentials: OK ($cred)" -ForegroundColor Green
} else {
  Write-Host "mooncakes credentials: not found (optional for moon add)" -ForegroundColor Yellow
  Write-Host "  Run: moon login   or   moon register"
}

Write-Step "Registry index"
Push-Location $ROOT
try {
  & moon update
  if ($LASTEXITCODE -ne 0) { throw "moon update failed" }
} finally {
  Pop-Location
}

Write-Step "Plugin repo (wasm-gc)"
Push-Location $ROOT
try {
  & moon check --target wasm-gc
  if ($LASTEXITCODE -ne 0) { throw "moon check failed" }
  & moon test --target wasm-gc
  if ($LASTEXITCODE -ne 0) { throw "moon test failed" }
} finally {
  Pop-Location
}

Write-Step "Consumer smoke test (moon add + check)"
Remove-Item -Recurse -Force $SMOKE -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $SMOKE | Out-Null

Write-JsonNoBom (Join-Path $SMOKE "moon.mod.json") @"
{
  "name": "Mairzzcllo/sqlc_consumer_smoke",
  "version": "0.0.1",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc",
  "deps": {
    "$Package": "$Version"
  }
}
"@

Write-JsonNoBom (Join-Path $SMOKE "moon.pkg") @"
import {
  "$Package/runtime" @runtime,
}
"@

Write-JsonNoBom (Join-Path $SMOKE "smoke.mbt") @"
///|
test "runtime import smoke" {
  let db = @runtime.MockDB::default_ok().build()
  let _ = db
}
"@

Push-Location $SMOKE
try {
  & moon update
  if ($LASTEXITCODE -ne 0) { throw "moon update in smoke project failed" }
  & moon check --target wasm-gc
  if ($LASTEXITCODE -ne 0) { throw "consumer moon check failed" }
  & moon test --target wasm-gc
  if ($LASTEXITCODE -ne 0) { throw "consumer moon test failed" }
} finally {
  Pop-Location
}

Write-Step "Native backend skip (expected on Windows wasm-only setup)"
Push-Location $ROOT
try {
  $nativeOut = & moon check --target native 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "native check unexpectedly passed" -ForegroundColor Yellow
  } else {
    Write-Host "native check skipped as expected (wasm-only project)" -ForegroundColor Green
  }
} catch {
  Write-Host "native check skipped as expected (wasm-only project)" -ForegroundColor Green
} finally {
  Pop-Location
}

Write-Host "`n[OK] mooncakes runtime $Package@$Version works on Windows (wasm-gc)." -ForegroundColor Green
Write-Host "Use in your app:"
Write-Host "  moon add ${Package}@${Version}"
Write-Host "  moon check --target wasm-gc"
