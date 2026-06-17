# Sync MoonBit agent skills from https://github.com/moonbitlang/skills
# Project-local only — does not modify global ~/.cursor or ~/.agents

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SkillsDir = Join-Path $RepoRoot ".cursor\skills"
$Zip = Join-Path $env:TEMP "moonbit-skills.zip"
$Extract = Join-Path $env:TEMP "moonbit-skills-extract"

Write-Host "Syncing moonbitlang/skills -> $SkillsDir"

try {
    npx skills@latest add moonbitlang/skills --agent cursor --skill "*" --copy -y
    Write-Host "Installed via skills CLI."
    exit 0
} catch {
    Write-Host "skills CLI failed ($($_.Exception.Message)); falling back to zip download..."
}

Invoke-WebRequest -Uri "https://github.com/moonbitlang/skills/archive/refs/heads/master.zip" `
    -OutFile $Zip -UseBasicParsing
if (Test-Path $Extract) { Remove-Item $Extract -Recurse -Force }
Expand-Archive -Path $Zip -DestinationPath $Extract -Force

$Src = Join-Path $Extract "skills-master\skills"
if (-not (Test-Path $Src)) {
    throw "Unexpected archive layout: $Src not found"
}

New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
Get-ChildItem $Src -Directory | ForEach-Object {
    $Target = Join-Path $SkillsDir $_.Name
    if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }
    Copy-Item -Path $_.FullName -Destination $Target -Recurse -Force
    Write-Host "  + $($_.Name)"
}

Write-Host "Done. $($((Get-ChildItem $SkillsDir -Directory).Count)) skills in .cursor/skills/"
