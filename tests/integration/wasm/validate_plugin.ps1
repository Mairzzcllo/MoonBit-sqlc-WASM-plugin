# validate_plugin.ps1 — P0-032 WASM Plugin Validation
# Validates the built plugin.wasm binary for sqlc compatibility.
# Native WASI I/O via inline WAT FFI (no shim merging needed).
#
# Prerequisites:
#   1. moon build --target wasm   (MoonBit toolchain)
#   2. wabt                       (for wasm2wat, optional)
#   3. sqlc version               (optional, for end-to-end test)
#
# Usage: .\validate_plugin.ps1 [-TestSqlc]
#   -TestSqlc      : Run sqlc generate end-to-end
#   Default: run all checks

param(
  [switch]$TestSqlc = $false
)

$ErrorActionPreference = "Continue"
$ROOT = Resolve-Path "$PSScriptRoot\..\..\.."
$BUILD_DIR = "$ROOT\_build"
$PLUGIN_WASM = "$BUILD_DIR\plugin.wasm"
$SQLC_YAML = "$ROOT\examples\users\sqlc.yaml"
$PASS = 0
$FAIL = 0
$SKIP = 0

function Test-Step {
  param([string]$Name, [scriptblock]$Body)
  try {
    & $Body
    Write-Host "  [PASS] $Name" -ForegroundColor Green
    $script:PASS++
  } catch {
    Write-Host "  [FAIL] $Name`: $_" -ForegroundColor Red
    $script:FAIL++
  }
}

function Skip-Step {
  param([string]$Name, [string]$Reason)
  Write-Host "  [SKIP] $Name — $Reason" -ForegroundColor Yellow
  $script:SKIP++
}

Write-Host "`n=== MoonBit sqlc WASM Plugin — P0-032 Validation ===" -ForegroundColor Cyan
Write-Host "Root: $ROOT`n"

# --- Step 0: Prerequisites ---
Test-Step "MoonBit toolchain available" {
  $v = & moon --version 2>&1
  if (-not $v) { throw "moon not found" }
}

# --- Step 1: Build ---
Write-Host "`n--- Step 1: Build Pipeline ---" -ForegroundColor Cyan

Write-Host "  Running moon build --target wasm ..."
$buildOutput = & moon build --target wasm 2>&1
if ($LASTEXITCODE -eq 0) {
  Test-Step "moon build --target wasm" { $true }
} else {
  Test-Step "moon build --target wasm" { throw $buildOutput }
}

Test-Step "plugin.wasm was produced" {
  if (-not (Test-Path $PLUGIN_WASM)) { throw "plugin.wasm not found at $PLUGIN_WASM" }
  $size = (Get-Item $PLUGIN_WASM).Length
  Write-Host "($size bytes)" -NoNewline
  if ($size -eq 0) { throw "plugin.wasm is empty" }
  if ($size -le 500) { throw "plugin.wasm is too small ($size bytes) — expected ~170KB" }
}

# --- Step 2: WASM Binary Validation ---
Write-Host "`n--- Step 2: WASM Binary Validation ---" -ForegroundColor Cyan

if (Get-Command wasm2wat -ErrorAction SilentlyContinue) {
  Test-Step "wasm2wat can decode plugin.wasm" {
    $wat = & wasm2wat $PLUGIN_WASM 2>&1
    if (-not $wat) { throw "wasm2wat produced no output" }
    if ($wat -notmatch "export.*_start") { throw "WAT has no _start export" }
  }

  Test-Step "plugin.wasm has expected structure" {
    $wat = & wasm2wat $PLUGIN_WASM 2>&1
    if ($wat -notmatch "import.*wasi_snapshot_preview1.*fd_read") {
      throw "Missing WASI fd_read import"
    }
    if ($wat -notmatch "import.*wasi_snapshot_preview1.*fd_write") {
      throw "Missing WASI fd_write import"
    }
    if ($wat -notmatch "export.*_start") {
      throw "Missing _start export"
    }
    Write-Host "(fd_read + fd_write + _start present)" -NoNewline
  }
} else {
  Skip-Step "WASM binary validation" "wabt not installed (npm i -g wabt)"
}

# --- Step 3: moon test ---
Write-Host "`n--- Step 3: MoonBit Tests ---" -ForegroundColor Cyan
$testOutput = & moon test 2>&1
if ($LASTEXITCODE -eq 0) {
  Test-Step "moon test (all tests pass)" { $true }
} else {
  Test-Step "moon test (all tests pass)" { throw $testOutput }
}

# --- Step 4: sqlc generate End-to-End ---
if ($TestSqlc) {
  Write-Host "`n--- Step 4: sqlc generate End-to-End ---" -ForegroundColor Cyan

  Test-Step "sqlc.yaml exists" {
    if (-not (Test-Path $SQLC_YAML)) { throw "sqlc.yaml not found at $SQLC_YAML" }
  }

  if (Get-Command sqlc -ErrorAction SilentlyContinue) {
    Test-Step "sqlc version" {
      $v = & sqlc version 2>&1
      if (-not $v) { throw "sqlc version check failed" }
      Write-Host "($v)" -NoNewline
    }

    Test-Step "sqlc generate produces output" {
      Push-Location "$ROOT\examples\users"
      try {
        $output = & sqlc generate 2>&1
        $exitCode = $LASTEXITCODE
        $text = ($output | ForEach-Object { "$_" }) -join "`n"
        if ($exitCode -ne 0) {
          throw "sqlc generate failed (exit $exitCode): $text"
        }
      } finally {
        Pop-Location
      }
    }
  } else {
    Skip-Step "sqlc generate" "sqlc not installed"
  }
} else {
  Skip-Step "sqlc generate" "skipped by flag (use -TestSqlc)"
}

# --- Summary ---
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
$TOTAL = $PASS + $FAIL + $SKIP
Write-Host "  Total: $TOTAL | Pass: $PASS | Fail: $FAIL | Skip: $SKIP" -ForegroundColor $(if ($FAIL -gt 0) { "Red" } else { "Green" })
if ($FAIL -gt 0) {
  exit 1
}
exit 0
