[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gitDir = (git -C $repoRoot rev-parse --git-dir).Trim()
if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
    $gitDir = Join-Path $repoRoot $gitDir
}

$hooksDir = Join-Path $gitDir 'hooks'
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

$preCommit = @'
#!/bin/sh
set -eu
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(git rev-parse --show-toplevel)/.safety/verify-public-repo.ps1" -Mode Staged
'@

$prePush = @'
#!/bin/sh
set -eu
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(git rev-parse --show-toplevel)/.safety/verify-public-repo.ps1" -Mode PrePush -RemoteUrl "${2:-}"
'@

[System.IO.File]::WriteAllText((Join-Path $hooksDir 'pre-commit'), $preCommit, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $hooksDir 'pre-push'), $prePush, [System.Text.UTF8Encoding]::new($false))
Write-Host "Installed public repository safety hooks in $hooksDir"

