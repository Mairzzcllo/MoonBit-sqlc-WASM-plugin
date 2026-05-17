#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Merge WAT shim into MoonBit WASM plugin, producing final plugin.wasm
.DESCRIPTION
  Build pipeline for MoonBit sqlc WASM plugin:
    1. moon build --target wasm       → produce .core files
    2. moonc link-core                 → produce full .wat
    3. Resolve mangled function names for shim placeholders
    4. Text-merge shim/wasi_shim.wat   → merged.wat
    5. wat2wasm / wasm-opt             → plugin.wasm
.NOTES
  Requires: moon, moonc, wabt (npm i -g wabt)
  Output:   _build/plugin.wasm
#>

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "_build"
$WasmBuildDir = Join-Path $BuildDir "wasm\debug\build"
$PluginCore = Join-Path $WasmBuildDir "plugin\plugin.core"
$StdBundle = Join-Path $env:USERPROFILE ".moon\lib\core\_build\wasm\release\bundle\core.core"
$ShimWat = Join-Path $ProjectRoot "shim\wasi_shim.wat"
$LinkedWat = Join-Path $BuildDir "linked.wat"
$MergedWat = Join-Path $BuildDir "merged.wat"
$OutputWasm = Join-Path $BuildDir "plugin.wasm"

Write-Host "=== MoonBit sqlc WASM Plugin — Build + Shim Merge ===" -ForegroundColor Cyan

# ---- Step 1: moon build ---------------------------------------------------
Write-Host "[1/5] moon build --target wasm ..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
  $buildResult = moon build --target wasm 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "moon build failed:" -ForegroundColor Red
    $buildResult | ForEach-Object { Write-Host $_ }
    exit 1
  }
  Write-Host "  OK" -ForegroundColor Green
} finally {
  Pop-Location
}

# ---- Step 2: moonc link-core (produce full WAT) ---------------------------
Write-Host "[2/5] moonc link-core -> linked.wat ..." -ForegroundColor Yellow
$linkArgs = @(
  "link-core"
  "-o", $LinkedWat
  "-target", "wasm"
  "-main", "Mairzzcllo/moonbit_sqlc_plugin/plugin"
  "`"$PluginCore`""
  "`"$StdBundle`""
  "-pkg-config-path", "plugin/moon.pkg"
)
$linkResult = & moonc $linkArgs 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "moonc link-core failed:" -ForegroundColor Red
  $linkResult | ForEach-Object { Write-Host $_ }
  exit 1
}

$linkedContent = Get-Content -LiteralPath $LinkedWat -Raw
$isStub = $linkedContent.Length -le 500
if ($isStub) {
  Write-Host "  WARNING: linked.wat is minimal ($($linkedContent.Length) bytes)" -ForegroundColor Yellow
  Write-Host "  MoonBit --target wasm produces .core files; moonc link-core emits only the entry stub." -ForegroundColor Yellow
  Write-Host "  Full WASM codegen requires MoonBit toolchain update for standalone WASM output." -ForegroundColor Yellow
  Write-Host "  For now, the shim is merged at the WAT level for documentation/validation." -ForegroundColor Yellow
} else {
  Write-Host "  linked.wat: $($linkedContent.Length) bytes" -ForegroundColor Green
}

# ---- Step 3: Resolve mangled function names --------------------------------
Write-Host "[3/5] Resolving mangled function names ..." -ForegroundColor Yellow

# In stub mode, the function name is literal from the linked.wat fragment
$processMessageName = '$process_message'   # keep original in stub mode
$moonbitInitName = '$_M0FP017____moonbit__main'   # stub fragment name

if (-not $isStub) {
  $found = Select-String -LiteralPath $LinkedWat -Pattern '(func \$\S*process__message)' -Raw
  if ($found) {
    $processMessageName = $found.Matches.Groups[1].Value -replace '^func ', ''
  }
  $startFound = Select-String -LiteralPath $LinkedWat -Pattern 'export "_start" \(func (\$\S+)\)' -Raw
  if ($startFound) {
    $moonbitInitName = $startFound.Matches.Groups[1].Value
  }
}
Write-Host "  moonbit_init:   $moonbitInitName" -ForegroundColor Green
Write-Host "  process_message: $processMessageName" -ForegroundColor Green

# ---- Step 4: Text-merge shim into linked WAT ------------------------------
Write-Host "[4/5] Merging shim/wasi_shim.wat -> merged.wat ..." -ForegroundColor Yellow

# Read shim WAT and resolve placeholders
# NOTE: PowerShell -replace interprets $ in replacement strings ($$ = literal $, $_ = entire match)
# Must escape $ to $$ for literal replacement
$shimContent = Get-Content -LiteralPath $ShimWat -Raw
$escapedInit = $moonbitInitName -replace '\$', '$$$$'
$escapedProc = $processMessageName -replace '\$', '$$$$'
$shimContent = $shimContent -replace '\$moonbit_init', $escapedInit
$shimContent = $shimContent -replace '\$process_message', $escapedProc

# Extract shim internals: strip (module) wrapper and all import blocks
# Step 1: Strip opening (module) header line
$shimBody = $shimContent -replace '(?m)^\s*\(module\b.*\n?', ''
# Step 2: Remove all (import ... ) blocks (paren-depth counting)
$result = ''
$depth = 0
$inImport = $false
for ($i = 0; $i -lt $shimBody.Length; $i++) {
  $c = $shimBody[$i]
  if (-not $inImport) {
    if ($c -eq '(' -and $i + 7 -lt $shimBody.Length -and $shimBody.Substring($i, 7) -eq '(import') {
      $inImport = $true
      $depth = 1
      continue
    }
    $result += $c
  } else {
    if ($c -eq '(') { $depth++ }
    elseif ($c -eq ')') { $depth--; if ($depth -eq 0) { $inImport = $false } }
  }
}
$shimBody = $result
# Step 3: Remove trailing ) that closes the module
$shimBody = $shimBody.TrimEnd() -replace '\)$', ''

# linkedContent already loaded from linked.wat (Step 2)

# Remove MoonBit's _start export (shim provides replacement)
$linkedContent = $linkedContent -replace '\(export "_start" [^)]*\)\s*\)\s*', ''

# Build the merged module: imports first, then MoonBit defs, then shim
$wasiImports = @'
  (import "wasi_snapshot_preview1" "fd_read"
    (func $wasi_fd_read (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $wasi_fd_write (param i32 i32 i32 i32) (result i32)))

'@

# Stub implementations for MoonBit runtime functions (only used in stub mode)
$moonbitStubs = @'
  ;; Stub: moonbit.bytes_make_raw
  (func $moonbit.bytes_make_raw (param $len i32) (result i32)
    i32.const 0)

  ;; Stub: process_message
  (func $process_message (param $input i32) (result i32)
    i32.const 0)

'@

$mergedContent = @"
(module
  $wasiImports
$linkedContent
$moonbitStubs
$shimBody
)
"@

# Validate balanced parens
$openCount = ([regex]::Matches($mergedContent, '\(')).Count
$closeCount = ([regex]::Matches($mergedContent, '\)')).Count
if ($openCount -ne $closeCount) {
  Write-Host "  WARNING: unbalanced parentheses ($openCount open, $closeCount close)" -ForegroundColor Yellow
}

[System.IO.File]::WriteAllText($MergedWat, $mergedContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "  merged.wat: $((Get-Item $MergedWat).Length) bytes" -ForegroundColor Green

# ---- Step 5: Compile merged WAT to WASM -----------------------------------
Write-Host "[5/5] Compiling merged.wat -> plugin.wasm ..." -ForegroundColor Yellow

$wat2wasm = Get-Command wat2wasm -ErrorAction SilentlyContinue
if ($wat2wasm) {
  & wat2wasm $MergedWat -o $OutputWasm 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  wat2wasm -> plugin.wasm: $((Get-Item $OutputWasm).Length) bytes" -ForegroundColor Green
  } else {
    Write-Host "  wat2wasm failed" -ForegroundColor Red
  }
} else {
  Write-Host "  No WASM toolchain found for WAT→WASM compilation." -ForegroundColor Yellow
  Write-Host "  Install: npm install -g wabt" -ForegroundColor Cyan
}

Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Outputs:" -ForegroundColor Cyan
Write-Host "  $LinkedWat    — MoonBit linked WAT"
Write-Host "  $MergedWat    — Merged WAT (MoonBit + shim)"
Write-Host "  $OutputWasm   — Final WASM plugin (if compilation succeeded)"
