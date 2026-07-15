[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'verify-public-repo.ps1') -Mode Full

$paths = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'allowed-files.txt') -Encoding utf8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

$missing = @($paths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repoRoot $_)) })
if ($missing.Count -gt 0) {
    throw "Allowlisted files are missing: $($missing -join ', ')"
}

git -C $repoRoot add -- $paths
& (Join-Path $PSScriptRoot 'verify-public-repo.ps1') -Mode Staged
Write-Host "Staged exactly $($paths.Count) allowlisted public files."

