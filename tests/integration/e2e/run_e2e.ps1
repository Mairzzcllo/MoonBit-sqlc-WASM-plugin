# run_e2e.ps1 — P1-037 E2E Integration Test
# Builds the WASM plugin, runs sqlc generate on examples/users, and validates output.
#
# Usage:
#   .\tests\integration\e2e\run_e2e.ps1
#   .\tests\integration\e2e\run_e2e.ps1 -SkipBuild         # Skip moon build (assume already built)
#   .\tests\integration\e2e\run_e2e.ps1 -DownloadSqlc      # Download sqlc if not found in PATH
#
# Prerequisites:
#   - MoonBit toolchain (moon build --target wasm)
#   - sqlc CLI (automatically downloaded if -DownloadSqlc is set)
#
# Output files checked (aligned with scripts/run-example.ps1):
#   - examples/users/types.mbt   (contains "pub struct User")
#   - examples/users/queries.mbt (contains "pub fn query_")

param(
  [switch]$SkipBuild = $false,
  [switch]$DownloadSqlc = $false,
  [switch]$Release = $false
)

$ErrorActionPreference = "Continue"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
$ROOT = Resolve-Path "$PSScriptRoot\..\..\.."
$BUILD_DIR = "$ROOT\_build"
$BUILD_MODE = if ($Release) { "release" } else { "debug" }
$PLUGIN_WASM = "$BUILD_DIR\wasm\$BUILD_MODE\build\plugin\plugin.wasm"
$EXAMPLE_DIR = "$ROOT\examples\users"
$SQLC_YAML = "$EXAMPLE_DIR\sqlc.yaml"
$TYPES_MBT = "$EXAMPLE_DIR\types.mbt"
$QUERIES_MBT = "$EXAMPLE_DIR\queries.mbt"
$PASS = 0
$FAIL = 0
$SKIP = 0

function Read-RequiredContent {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "file not found: $Path"
  }
  $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
  if ([string]::IsNullOrWhiteSpace($content)) {
    throw "file is empty: $Path"
  }
  return $content
}

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
  if (Get-Command sqlc -ErrorAction SilentlyContinue) {
    $v = & sqlc version 2>&1
    Write-Host "  Using sqlc: $v"
    return $true
  }

  if ($IsLinux) { $os = "linux" }
  elseif ($IsMacOS) { $os = "darwin" }
  else { $os = "windows" }

  $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
  $binName = if ($os -eq "windows") { "sqlc.exe" } else { "sqlc" }
  $localSqlc = "$ROOT\bin\$binName"

  if (Test-Path $localSqlc) {
    $env:PATH = "$ROOT\bin;$env:PATH"
    $v = & sqlc version 2>&1
    Write-Host "  Using sqlc (local): $v"
    return $true
  }

  if ($Download) {
    Write-Host "  Downloading sqlc ..."
    $tmp = "$env:TEMP\sqlc.zip"
    $version = "1.31.1"
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
  $buildArgs = @("build", "--target", "wasm")
  if ($Release) { $buildArgs += "--release" }
  Write-Host "  Running moon $($buildArgs -join ' ') ..."
  $buildOutput = & moon @buildArgs 2>&1
  if ($LASTEXITCODE -eq 0) {
    Test-Step "moon build --target wasm ($BUILD_MODE)" { $true }
  } else {
    Test-Step "moon build --target wasm ($BUILD_MODE)" { throw ($buildOutput -join "`n") }
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
Write-Host "`n--- Step 2: Verify examples/users/sqlc.yaml ---" -ForegroundColor Cyan

Test-Step "sqlc.yaml exists" {
  if (-not (Test-Path $SQLC_YAML)) {
    throw "sqlc.yaml not found at $SQLC_YAML"
  }
}

Test-Step "sqlc.yaml references plugin.wasm" {
  $content = Read-RequiredContent -Path $SQLC_YAML
  if ($content -notmatch "plugin\.wasm") {
    throw "sqlc.yaml does not reference plugin.wasm"
  }
}

Test-Step "schema.sql exists" {
  $schemaPath = "$EXAMPLE_DIR\schema.sql"
  if (-not (Test-Path $schemaPath)) {
    throw "schema.sql not found at $schemaPath"
  }
}

Test-Step "query.sql exists" {
  $queryPath = "$EXAMPLE_DIR\query.sql"
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

  Remove-Item $TYPES_MBT -Force -ErrorAction SilentlyContinue
  Remove-Item $QUERIES_MBT -Force -ErrorAction SilentlyContinue

  Test-Step "sqlc.yaml url + sha256 synced to built plugin.wasm" {
    if ($Release) {
      & "$ROOT\scripts\sync-sqlc-sha256.ps1" -WasmPath $PLUGIN_WASM -YamlPath $SQLC_YAML -Release
    } else {
      & "$ROOT\scripts\sync-sqlc-sha256.ps1" -WasmPath $PLUGIN_WASM -YamlPath $SQLC_YAML
    }
    if ($LASTEXITCODE -ne 0) { throw "sync-sqlc-sha256 failed" }
  }

  Test-Step "sqlc generate succeeded" {
    Push-Location $EXAMPLE_DIR
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
  Read-RequiredContent -Path $TYPES_MBT | Out-Null
}

Test-Step "queries.mbt is non-empty" {
  Read-RequiredContent -Path $QUERIES_MBT | Out-Null
}

Test-Step "types.mbt contains package declaration" {
  $content = Read-RequiredContent -Path $TYPES_MBT
  if ($content -notmatch "package\s+\w+") {
    throw "types.mbt should contain a package declaration"
  }
}

Test-Step "types.mbt contains pub struct User" {
  $content = Read-RequiredContent -Path $TYPES_MBT
  if ($content -notmatch "pub struct User") {
    throw "types.mbt should contain 'pub struct User' (singularized from users table)"
  }
}

Test-Step "types.mbt contains runtime import" {
  $content = Read-RequiredContent -Path $TYPES_MBT
  if ($content -notmatch "Mairzzcllo/moonbit_sqlc_plugin/runtime") {
    throw "types.mbt should import the runtime library"
  }
}

Test-Step "queries.mbt contains pub fn query_" {
  $content = Read-RequiredContent -Path $QUERIES_MBT
  if ($content -notmatch "pub fn query_") {
    throw "queries.mbt should contain at least one 'pub fn query_'"
  }
}

Test-Step "queries.mbt contains row decode call" {
  $content = Read-RequiredContent -Path $QUERIES_MBT
  if ($content -notmatch "::decode") {
    throw "queries.mbt should reference a ::decode method for row decoding"
  }
}

Test-Step "queries.mbt contains GetUserRow::decode" {
  $content = Read-RequiredContent -Path $QUERIES_MBT
  if ($content -notmatch "GetUserRow::decode") {
    throw "queries.mbt should reference GetUserRow::decode for :one query decoding"
  }
}

Test-Step "queries.mbt contains runtime import" {
  $content = Read-RequiredContent -Path $QUERIES_MBT
  if ($content -notmatch "Mairzzcllo/moonbit_sqlc_plugin/runtime") {
    throw "queries.mbt should import the runtime library"
  }
}

Test-Step "query functions named correctly for users queries" {
  $content = Read-RequiredContent -Path $QUERIES_MBT
  $hasOne = $content -match "pub fn query_get_user"
  $hasMany = $content -match "pub fn query_list_users"
  if (-not $hasOne) { throw "queries.mbt missing query_get_user (:one)" }
  if (-not $hasMany) { throw "queries.mbt missing query_list_users (:many)" }
  Write-Host "(:one + :many present)" -NoNewline
}

# --- Step 5: Integration Cross-Check ---
Write-Host "`n--- Step 5: Integration Cross-Check ---" -ForegroundColor Cyan

Test-Step "generated types.mbt does not contain query functions" {
  $content = Read-RequiredContent -Path $TYPES_MBT
  if ($content -match "pub fn query_") {
    throw "types.mbt should NOT contain query_ function declarations"
  }
}

Test-Step "generated queries.mbt does not contain struct definitions" {
  $content = Read-RequiredContent -Path $QUERIES_MBT
  if ($content -match "pub struct Users") {
    throw "queries.mbt should NOT contain struct definitions"
  }
}

Test-Step "generated files have consistent package name" {
  $typesContent = Read-RequiredContent -Path $TYPES_MBT
  $queriesContent = Read-RequiredContent -Path $QUERIES_MBT
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

# --- Step 6: Compile generated code against runtime ---
Write-Host "`n--- Step 6: Runtime compile check ---" -ForegroundColor Cyan

Test-Step "moon check tests/integration/runtime" {
  Push-Location $ROOT
  try {
    $output = & moon check tests/integration/runtime 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { "$_" }) -join "`n"
    if ($exitCode -ne 0) {
      throw "moon check tests/integration/runtime failed (exit $exitCode): $text"
    }
  } finally {
    Pop-Location
  }
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
