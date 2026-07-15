[CmdletBinding()]
param(
    [ValidateSet('Full', 'Staged', 'PrePush')]
    [string]$Mode = 'Full',
    [string]$RemoteUrl = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resolvedGitRoot = (git -C $repoRoot rev-parse --show-toplevel 2>$null).Trim()
if (-not $resolvedGitRoot -or (Resolve-Path $resolvedGitRoot).Path -ne $repoRoot) {
    throw 'Safety check must run from the isolated StabiLink-Public repository.'
}

$privateRoot = [Environment]::GetEnvironmentVariable('STABILINK_PRIVATE_ROOT')
if ($privateRoot -and $repoRoot.StartsWith([IO.Path]::GetFullPath($privateRoot), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Public repository must never be nested inside a private source repository.'
}

$allowlistPath = Join-Path $PSScriptRoot 'allowed-files.txt'
$allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
Get-Content -LiteralPath $allowlistPath -Encoding utf8 | ForEach-Object {
    $item = $_.Trim().Replace('\', '/')
    if ($item -and -not $item.StartsWith('#')) { [void]$allowed.Add($item) }
}

function Get-RelativeFiles {
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force |
        Where-Object { $_.FullName -notlike "$repoRoot\.git\*" } |
        ForEach-Object { $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/') }
}

$dangerousExtensions = @(
    '.cs', '.xaml', '.csproj', '.sln', '.suo', '.vb', '.fs', '.cpp', '.c', '.h',
    '.dll', '.exe', '.pdb', '.zip', '.7z', '.rar', '.tar', '.gz', '.nupkg',
    '.db', '.sqlite', '.bak', '.old', '.log', '.config', '.pem', '.key', '.pfx',
    '.p12', '.cer', '.crt', '.patch', '.diff', '.bundle'
)

$dangerousNames = @(
    'appsettings.json', 'appsettings.production.json', 'config.json', 'local.json',
    '.env', '.env.local', '.env.production', 'packages.lock.json'
)

$errors = [System.Collections.Generic.List[string]]::new()
$files = @(Get-RelativeFiles)
foreach ($file in $files) {
    if (-not $allowed.Contains($file)) {
        $errors.Add("File is not in public allowlist: $file")
    }

    $name = [System.IO.Path]::GetFileName($file).ToLowerInvariant()
    $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
    $isSafetyScript = $file -in @(
        '.safety/install-hooks.ps1',
        '.safety/stage-allowlisted.ps1',
        '.safety/verify-public-repo.ps1'
    )
    if (($dangerousExtensions -contains $extension) -or ($dangerousNames -contains $name)) {
        $errors.Add("Forbidden file type/name: $file")
    }
    if ($extension -eq '.ps1' -and -not $isSafetyScript) {
        $errors.Add("Only audited safety PowerShell scripts are allowed: $file")
    }

    $item = Get-Item -LiteralPath (Join-Path $repoRoot $file)
    if ($item.Length -gt 10MB) {
        $errors.Add("Git file exceeds 10 MB; use a Release asset instead: $file")
    }
}

$tracked = @(git -C $repoRoot ls-files | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
foreach ($file in $tracked) {
    if (-not $allowed.Contains($file)) { $errors.Add("Tracked file is not allowed: $file") }
}

$historyFiles = @(git -C $repoRoot log --all --name-only --format= 2>$null | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ } | Sort-Object -Unique)
foreach ($file in $historyFiles) {
    if (-not $allowed.Contains($file)) { $errors.Add("Forbidden path exists in Git history: $file") }
}

if ($Mode -eq 'Staged') {
    $staged = @(git -C $repoRoot diff --cached --name-only --diff-filter=ACMR | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    foreach ($file in $staged) {
        if (-not $allowed.Contains($file)) { $errors.Add("Staged file is not allowed: $file") }
    }
}

if ($Mode -eq 'PrePush') {
    $allowedRemotes = @(
        'https://github.com/sany86russ/StabiLink-Desktop.git',
        'git@github.com:sany86russ/StabiLink-Desktop.git'
    )
    if ($RemoteUrl -notin $allowedRemotes) {
        $errors.Add("Push destination is not the approved public repository: $RemoteUrl")
    }
}

$textExtensions = @('.md', '.txt', '.yml', '.yaml', '.gitignore', '.gitattributes', '.ps1')
$secretPatterns = @(
    '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)authorization\s*:\s*(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}',
    '(?i)(?:api[_-]?key|client[_-]?secret|access[_-]?token|refresh[_-]?token|password)\s*[:=]\s*["''][^"'']{6,}["'']',
    '(?i)\bgh[pousr]_[A-Za-z0-9]{20,}\b',
    '(?i)\bsk-[A-Za-z0-9_-]{20,}\b'
)

foreach ($file in $files) {
    $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
    if ($textExtensions -contains $extension -or $file -in @('.gitignore', '.gitattributes')) {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot $file) -Raw -Encoding utf8
        foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) { $errors.Add("Possible secret in: $file") }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    throw "Public repository safety check failed with $($errors.Count) finding(s)."
}

Write-Host "Public repository safety check passed ($Mode): $($files.Count) allowlisted files."
