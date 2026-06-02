# run_e2e.ps1 — P1-037 E2E Integration Test
# Builds the WASM plugin, runs sqlc generate, and validates output.
#
# Usage:
#   .\tests\integration\e2e\run_e2e.ps1
#   .\tests\integration\e2e\run_e2e.ps1 -SkipBuild         # Skip moon build (assume already built)
#   .\tests\integration\e2e\run_e2e.ps1 -DownloadSqlc      # Download sqlc.exe if not found in PATH
#
# Prerequisites:
#   - MoonBit toolchain (moon build --target wasm)
#   - sqlc CLI (automatically downloaded if -DownloadSqlc is set)
#
# Output files checked:
#   - examples/users/types.mbt   (contains "pub struct Users")
#   - examples/users/queries.mbt (contains "pub fn query_")

param(
  [switch]$SkipBuild = $false,
  [switch]$DownloadSqlc = $false
)

$ErrorActionPreference = "Continue"
$ROOT = Resolve-Path "$PSScriptRoot\..\..\.."
$BUILD_DIR = "$ROOT\_build"
$PLUGIN_WASM = "$BUILD_DIR\wasm\debug\build\plugin\plugin.wasm"
$SQLC_YAML = "$ROOT\sqlc.yaml"
$GEN_DIR = "$ROOT\gen"
$TYPES_MBT = "$GEN_DIR\types.mbt"
$QUERIES_MBT = "$GEN_DIR\queries.mbt"
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

function Ensure-Sqlc {
  param([switch]$Download)
  # Check if sqlc is already in PATH
  if (Get-Command sqlc -ErrorAction SilentlyContinue) {
    $v = & sqlc version 2>&1
    Write-Host "  Using sqlc: $v"
    return $true
  }
  # Check local download
  $localSqlc = "$ROOT\bin\sqlc.exe"
  if (Test-Path $localSqlc) {
    $env:PATH = "$ROOT\bin;$env:PATH"
    $v = & sqlc version 2>&1
    Write-Host "  Using sqlc (local): $v"
    return $true
  }
  if ($Download) {
    Write-Host "  Downloading sqlc ..."
    $tmp = "$env:TEMP\sqlc.zip"
    $os = "windows"
    $arch = "amd64"
    # Detect architecture
    if ([Environment]::Is64BitOperatingSystem) {
      $arch = "amd64"
    } else {
      $arch = "386"
    }
    $version = "1.28.0"
    $url = "https://github.com/sqlc-dev/sqlc/releases/download/v${version}/sqlc_${version}_${os}_${arch}.zip"
    try {
      Invoke-WebRequest -Uri $url -OutFile $tmp -ErrorAction Stop
    } catch {
      Write-Host "  [WARN] Failed to download sqlc from $url"
      return $false
    }
    New-Item -ItemType Directory -Path "$ROOT\bin" -Force | Out-Null
    Expand-Archive -Path $tmp -DestinationPath "$ROOT\bin" -Force
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    $env:PATH = "$ROOT\bin;$env:PATH"
    if (Get-Command sqlc -ErrorAction SilentlyContinue) {
      $v = & sqlc version 2>&1
      Write-Host "  Using sqlc (downloaded): $v"
      return $true
    }
  }
  return $false
}

Write-Host "`n=== E2E Integration Test — P1-037 ===" -ForegroundColor Cyan
Write-Host "Root: $ROOT`n"

# --- Step 1: Build WASM Plugin ---
Write-Host "--- Step 1: Build WASM Plugin ---" -ForegroundColor Cyan

if (-not $SkipBuild) {
  Write-Host "  Running moon build --target wasm ..."
  $buildOutput = & moon build --target wasm 2>&1
  if ($LASTEXITCODE -eq 0) {
    Test-Step "moon build --target wasm" { $true }
  } else {
    Test-Step "moon build --target wasm" { throw ($buildOutput -join "`n") }
  }
} else {
  Skip-Step "moon build --target wasm" "skipped by -SkipBuild flag"
}

Test-Step "plugin.wasm exists" {
  if (-not (Test-Path $PLUGIN_WASM)) {
    throw "plugin.wasm not found at $PLUGIN_WASM"
  }
  $size = (Get-Item $PLUGIN_WASM).Length
  if ($size -eq 0) {
    throw "plugin.wasm is empty"
  }
  if ($size -le 500) {
    throw "plugin.wasm is too small ($size bytes) — expected ~170KB+"
  }
  Write-Host "($size bytes)" -NoNewline
}

# --- Step 2: Verify sqlc.yaml ---
Write-Host "`n--- Step 2: Verify sqlc.yaml ---" -ForegroundColor Cyan

Test-Step "sqlc.yaml exists" {
  if (-not (Test-Path $SQLC_YAML)) {
    throw "sqlc.yaml not found at $SQLC_YAML"
  }
}

Test-Step "sqlc.yaml references plugin.wasm" {
  $content = Get-Content -LiteralPath $SQLC_YAML -Raw
  if ($content -notmatch "plugin\.wasm") {
    throw "sqlc.yaml does not reference plugin.wasm"
  }
}

Test-Step "schema.sql exists" {
  $schemaPath = "$ROOT\examples\users\schema.sql"
  if (-not (Test-Path $schemaPath)) {
    throw "schema.sql not found at $schemaPath"
  }
}

Test-Step "query.sql exists" {
  $queryPath = "$ROOT\examples\users\query.sql"
  if (-not (Test-Path $queryPath)) {
    throw "query.sql not found at $queryPath"
  }
}

# --- Step 3: Run sqlc generate ---
Write-Host "`n--- Step 3: Run sqlc generate ---" -ForegroundColor Cyan

$hasSqlc = Ensure-Sqlc -Download:$DownloadSqlc

if ($hasSqlc) {
  Test-Step "sqlc version check" {
    $v = & sqlc version 2>&1
    if (-not $v) { throw "sqlc version check returned nothing" }
    Write-Host "($v)" -NoNewline
  }

  # Clean up any previous generated files to ensure a fresh run
  Remove-Item $TYPES_MBT -Force -ErrorAction SilentlyContinue
  Remove-Item $QUERIES_MBT -Force -ErrorAction SilentlyContinue

  Test-Step "sqlc generate succeeded" {
    Push-Location $ROOT
    try {
      $output = & sqlc generate 2>&1
      $exitCode = $LASTEXITCODE
      $text = ($output | ForEach-Object { "$_" }) -join "`n"
      if ($exitCode -ne 0) {
        throw "sqlc generate failed (exit $exitCode): $text"
      }
      Write-Host "(generated)" -NoNewline
    } finally {
      Pop-Location
    }
  }
} else {
  Skip-Step "sqlc generate" "sqlc not found in PATH (use -DownloadSqlc to auto-download)"
}

# --- Step 4: Validate Output Files ---
Write-Host "`n--- Step 4: Validate Output Files ---" -ForegroundColor Cyan

Test-Step "types.mbt exists" {
  if (-not (Test-Path $TYPES_MBT)) {
    throw "types.mbt not found at $TYPES_MBT"
  }
}

Test-Step "queries.mbt exists" {
  if (-not (Test-Path $QUERIES_MBT)) {
    throw "queries.mbt not found at $QUERIES_MBT"
  }
}

Test-Step "types.mbt is non-empty" {
  $content = Get-Content -LiteralPath $TYPES_MBT -Raw
  if (-not $content -or $content.Trim().Length -eq 0) {
    throw "types.mbt exists but is empty"
  }
}

Test-Step "queries.mbt is non-empty" {
  $content = Get-Content -LiteralPath $QUERIES_MBT -Raw
  if (-not $content -or $content.Trim().Length -eq 0) {
    throw "queries.mbt exists but is empty"
  }
}

Test-Step "types.mbt contains package declaration" {
  $content = Get-Content -LiteralPath $TYPES_MBT -Raw
  if ($content -notmatch "package\s+\w+") {
    throw "types.mbt should contain a package declaration"
  }
}

Test-Step "types.mbt contains pub struct Users" {
  $content = Get-Content -LiteralPath $TYPES_MBT -Raw
  if ($content -notmatch "pub struct Users") {
    throw "types.mbt should contain 'pub struct Users'"
  }
}

Test-Step "types.mbt contains runtime import" {
  $content = Get-Content -LiteralPath $TYPES_MBT -Raw
  if ($content -notmatch "Mairzzcllo/moonbit_sqlc_plugin/runtime") {
    throw "types.mbt should import the runtime library"
  }
}

Test-Step "queries.mbt contains pub fn query_" {
  $content = Get-Content -LiteralPath $QUERIES_MBT -Raw
  if ($content -notmatch "pub fn query_") {
    throw "queries.mbt should contain at least one 'pub fn query_'"
  }
}

Test-Step "queries.mbt contains Users::decode" {
  $content = Get-Content -LiteralPath $QUERIES_MBT -Raw
  if ($content -notmatch "Users::decode") {
    throw "queries.mbt should reference Users::decode for row decoding"
  }
}

Test-Step "queries.mbt contains runtime import" {
  $content = Get-Content -LiteralPath $QUERIES_MBT -Raw
  if ($content -notmatch "Mairzzcllo/moonbit_sqlc_plugin/runtime") {
    throw "queries.mbt should import the runtime library"
  }
}

Test-Step "query functions named correctly for users queries" {
  $content = Get-Content -LiteralPath $QUERIES_MBT -Raw
  # Expect: query_get_user, query_list_users, query_create_user, query_delete_user
  # Check at least one of each command type exists
  $hasOne = $content -match "pub fn query_get_user"
  $hasMany = $content -match "pub fn query_list_users"
  if (-not $hasOne) { throw "queries.mbt missing query_get_user (:one)" }
  if (-not $hasMany) { throw "queries.mbt missing query_list_users (:many)" }
  Write-Host "(:one + :many present)" -NoNewline
}

# --- Step 5: Integration Cross-Check ---
Write-Host "`n--- Step 5: Integration Cross-Check ---" -ForegroundColor Cyan

Test-Step "generated types.mbt does not contain query functions" {
  $content = Get-Content -LiteralPath $TYPES_MBT -Raw
  if ($content -match "pub fn query_") {
    throw "types.mbt should NOT contain query_ function declarations"
  }
}

Test-Step "generated queries.mbt does not contain struct definitions" {
  $content = Get-Content -LiteralPath $QUERIES_MBT -Raw
  if ($content -match "pub struct Users") {
    throw "queries.mbt should NOT contain struct definitions"
  }
}

Test-Step "generated files have consistent package name" {
  $typesContent = Get-Content -LiteralPath $TYPES_MBT -Raw
  $queriesContent = Get-Content -LiteralPath $QUERIES_MBT -Raw
  $typesMatch = [regex]::Match($typesContent, 'package\s+(\w+)')
  $queriesMatch = [regex]::Match($queriesContent, 'package\s+(\w+)')
  if (-not $typesMatch.Success -or -not $queriesMatch.Success) {
    throw "Could not extract package name from generated files"
  }
  if ($typesMatch.Groups[1].Value -ne $queriesMatch.Groups[1].Value) {
    throw "Package name mismatch: types=$($typesMatch.Groups[1].Value), queries=$($queriesMatch.Groups[1].Value)"
  }
  Write-Host "(package: $($typesMatch.Groups[1].Value))" -NoNewline
}

# --- Summary ---
Write-Host "`n`n=== E2E Test Summary ===" -ForegroundColor Cyan
$TOTAL = $PASS + $FAIL + $SKIP
Write-Host "  Total: $TOTAL | Pass: $PASS | Fail: $FAIL | Skip: $SKIP" -ForegroundColor $(if ($FAIL -gt 0) { "Red" } else { "Green" })

if ($FAIL -gt 0) {
  Write-Host "`n  E2E test FAILED. Check output above for details." -ForegroundColor Red
  exit 1
}

Write-Host "  E2E test PASSED." -ForegroundColor Green
exit 0
