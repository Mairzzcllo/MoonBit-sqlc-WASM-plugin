# run-example.ps1 — One-click build + sqlc generate for examples/users
#
# Prerequisites: MoonBit (moon) and sqlc on PATH
#
# Usage (from repo root):
#   .\scripts\run-example.ps1
#   .\scripts\run-example.ps1 -Release
#   .\scripts\run-example.ps1 -SkipBuild    # reuse existing plugin.wasm
#   .\scripts\run-example.ps1 -Full         # also run moon check && moon test

param(
  [switch]$Release = $false,
  [switch]$SkipBuild = $false,
  [switch]$Full = $false
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

$ROOT = Resolve-Path (Join-Path $PSScriptRoot "..")
$EXAMPLE = Join-Path $ROOT "examples\users"
$SQLC_YAML = Join-Path $EXAMPLE "sqlc.yaml"

if ($Release) {
  $PLUGIN_WASM = Join-Path $ROOT "_build\wasm\release\build\plugin\plugin.wasm"
  $BUILD_ARGS = @("build", "--target", "wasm", "--release")
} else {
  $PLUGIN_WASM = Join-Path $ROOT "_build\wasm\debug\build\plugin\plugin.wasm"
  $BUILD_ARGS = @("build", "--target", "wasm")
}

function Require-Command {
  param([string]$Name, [string]$Hint)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name not found on PATH. $Hint"
  }
}

function Write-Step {
  param([string]$Message)
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

Write-Host "MoonBit sqlc WASM Plugin — run example" -ForegroundColor Cyan
Write-Host "Root: $ROOT"

Require-Command "moon" "Install: https://www.moonbitlang.com/download/"
Require-Command "sqlc" "Install: https://docs.sqlc.dev/en/latest/overview/install.html"

Write-Step "Toolchain"
& moon --version
& sqlc version

if ($Full) {
  Write-Step "moon check"
  Push-Location $ROOT
  try {
    & moon check
    if ($LASTEXITCODE -ne 0) { throw "moon check failed (exit $LASTEXITCODE)" }
  } finally {
    Pop-Location
  }

  Write-Step "moon test"
  Push-Location $ROOT
  try {
    & moon test
    if ($LASTEXITCODE -ne 0) { throw "moon test failed (exit $LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
}

if (-not $SkipBuild) {
  Write-Step ("moon " + ($BUILD_ARGS -join " "))
  Push-Location $ROOT
  try {
    & moon @BUILD_ARGS
    if ($LASTEXITCODE -ne 0) { throw "moon build failed (exit $LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
}

if (-not (Test-Path $PLUGIN_WASM)) {
  throw "plugin.wasm not found: $PLUGIN_WASM`nRun without -SkipBuild or build manually."
}

$wasmSize = (Get-Item $PLUGIN_WASM).Length
Write-Host "plugin.wasm: $PLUGIN_WASM ($wasmSize bytes)" -ForegroundColor Green

Write-Step "sqlc generate (examples/users)"
if ($Release) {
  & (Join-Path $ROOT "scripts\sync-sqlc-sha256.ps1") -WasmPath $PLUGIN_WASM -YamlPath $SQLC_YAML -Release
} else {
  & (Join-Path $ROOT "scripts\sync-sqlc-sha256.ps1") -WasmPath $PLUGIN_WASM -YamlPath $SQLC_YAML
}
if ($LASTEXITCODE -ne 0) { throw "sync-sqlc-sha256 failed (exit $LASTEXITCODE)" }
Push-Location $EXAMPLE
try {
  & sqlc generate
  if ($LASTEXITCODE -ne 0) { throw "sqlc generate failed (exit $LASTEXITCODE)" }
} finally {
  Pop-Location
}

if ($Release) {
  Write-Step "Restore sqlc.yaml to debug url (sha256 cleared for commit)"
  $yaml = Get-Content $SQLC_YAML -Raw
  $yaml = $yaml -replace '(?m)^(\s*)url: "(file://[^"]*wasm/release/build/plugin/plugin\.wasm)"', '${1}# url: "${2}"'
  $yaml = $yaml -replace '(?m)^(\s*)#\s*url: "(file://[^"]*wasm/debug/build/plugin/plugin\.wasm)"', '${1}url: "${2}"'
  $yaml = [regex]::Replace($yaml, '(?m)^(\s*sha256:\s*)".*"', '${1}""', 1)
  Set-Content -Path $SQLC_YAML -Value $yaml -NoNewline -Encoding utf8
}

$TYPES = Join-Path $EXAMPLE "types.mbt"
$QUERIES = Join-Path $EXAMPLE "queries.mbt"

foreach ($f in @($TYPES, $QUERIES)) {
  if (-not (Test-Path $f)) { throw "Expected output missing: $f" }
}

Write-Step "Generated output"
Write-Host "  types.mbt   ($((Get-Item $TYPES).Length) bytes)"
Write-Host "  queries.mbt ($((Get-Item $QUERIES).Length) bytes)"
Write-Host ""
Get-Content $TYPES -TotalCount 8
Write-Host "  ..."
Get-Content $QUERIES -TotalCount 8
Write-Host "  ..."

Write-Host "`n[OK] Example ready. Next steps:" -ForegroundColor Green
Write-Host "  - Inspect: examples/users/types.mbt, examples/users/queries.mbt"
Write-Host "  - Integrate: copy files into your app + see examples/users/moon.pkg.example"
Write-Host "  - Runtime:   moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4"
