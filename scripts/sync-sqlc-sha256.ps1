# sync-sqlc-sha256.ps1 — Patch sqlc.yaml wasm url + sha256 from a built plugin.wasm
#
# WASM sha256 varies by OS/toolchain; CI and local builds must sync after moon build.
# Committed sqlc.yaml files keep sha256: "" and debug url active — run this before sqlc generate.
#
# Usage:
#   pwsh scripts/sync-sqlc-sha256.ps1 -WasmPath _build/wasm/debug/build/plugin/plugin.wasm -YamlPath examples/users/sqlc.yaml
#   pwsh scripts/sync-sqlc-sha256.ps1 -WasmPath _build/wasm/release/build/plugin/plugin.wasm -YamlPath examples/users/sqlc.yaml -Release

param(
  [Parameter(Mandatory = $true)][string]$WasmPath,
  [Parameter(Mandatory = $true)][string]$YamlPath,
  [switch]$Release = $false
)

$ErrorActionPreference = "Stop"

$wasm = Resolve-Path -LiteralPath $WasmPath
$yamlFile = Resolve-Path -LiteralPath $YamlPath

if (-not (Test-Path -LiteralPath $wasm)) {
  throw "plugin.wasm not found: $wasm"
}

$useRelease = $Release -or ($WasmPath -match '[/\\]release[/\\]')

function Set-WasmUrlMode {
  param([string]$Content, [bool]$ReleaseMode)

  $debugActive = '(?m)^(\s*)url: "(file://[^"]*wasm/debug/build/plugin/plugin\.wasm)"'
  $debugCommented = '(?m)^(\s*)#\s*url: "(file://[^"]*wasm/debug/build/plugin/plugin\.wasm)"'
  $releaseActive = '(?m)^(\s*)url: "(file://[^"]*wasm/release/build/plugin/plugin\.wasm)"'
  $releaseCommented = '(?m)^(\s*)#\s*url: "(file://[^"]*wasm/release/build/plugin/plugin\.wasm)"'

  if ($ReleaseMode) {
    if ($Content -match $debugActive) {
      $Content = [regex]::Replace($Content, $debugActive, '${1}# url: "${2}"', 1)
    }
    if ($Content -match $releaseCommented) {
      $Content = [regex]::Replace($Content, $releaseCommented, '${1}url: "${2}"', 1)
    } elseif ($Content -notmatch $releaseActive) {
      throw "No release wasm url line (active or commented) in yaml"
    }
  } else {
    if ($Content -match $releaseActive) {
      $Content = [regex]::Replace($Content, $releaseActive, '${1}# url: "${2}"', 1)
    }
    if ($Content -match $debugCommented) {
      $Content = [regex]::Replace($Content, $debugCommented, '${1}url: "${2}"', 1)
    } elseif ($Content -notmatch $debugActive) {
      throw "No debug wasm url line (active or commented) in yaml"
    }
  }

  return $Content
}

$sha = (Get-FileHash -LiteralPath $wasm -Algorithm SHA256).Hash.ToLowerInvariant()
$content = Get-Content -LiteralPath $yamlFile -Raw

$content = Set-WasmUrlMode -Content $content -ReleaseMode $useRelease

if ($content -match '(?m)^(\s*sha256:\s*)".*"') {
  $content = [regex]::Replace($content, '(?m)^(\s*sha256:\s*)".*"', "`${1}`"$sha`"", 1)
} elseif ($content -match '(?m)^(\s*sha256:\s*)\S') {
  $content = [regex]::Replace($content, '(?m)^(\s*sha256:\s*)\S+', "`${1}`"$sha`"", 1)
} else {
  throw "No sha256: field in $yamlFile"
}

Set-Content -Path $yamlFile -Value $content -NoNewline -Encoding utf8
$mode = if ($useRelease) { "release" } else { "debug" }
Write-Host "sync-sqlc-sha256: $yamlFile ($mode url) -> $sha"
