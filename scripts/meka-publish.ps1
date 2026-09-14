[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$ExpectedText = "",

    [string]$LiveUrl = "https://bigdiazenergy.github.io/PHXR-parking-plan/",

    [switch]$AllowNoChanges
)

$ErrorActionPreference = "Stop"

function Fail($message) {
    Write-Error $message
    exit 1
}

function Run-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "git $($GitArgs -join ' ') failed."
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

if (-not (Test-Path ".git")) {
    Fail "This script must run from inside the PHXR-parking-plan repository."
}

$branch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) {
    Fail "Could not read the current git branch."
}
if ($branch -ne "main") {
    Fail "Refusing to publish from branch '$branch'. Switch to main first."
}

Run-Git @("fetch", "origin", "main")

$upstream = (& git rev-parse "@{u}" 2>$null).Trim()
if ($LASTEXITCODE -eq 0 -and $upstream) {
    $behind = (& git rev-list --count "HEAD..@{u}").Trim()
    if ($LASTEXITCODE -ne 0) {
        Fail "Could not compare local main with origin/main."
    }
    if ([int]$behind -gt 0) {
        Fail "Local main is behind origin/main. Run 'git pull --ff-only' before publishing."
    }
}

$status = & git status --porcelain=v1 --untracked-files=all
if ($LASTEXITCODE -ne 0) {
    Fail "Could not read git status."
}

$allowedFiles = @(
    "index.html",
    "fedex-yard-plan.html",
    "README.md",
    "AGENTS.md",
    "scripts/meka-publish.ps1"
)

$blocked = @()
foreach ($line in $status) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $path = $line.Substring(3).Trim()
    $path = $path -replace "\\", "/"
    if ($path -like "*.bak*" -or $path -like "*~" -or $path -like "*.tmp") {
        continue
    }
    if ($allowedFiles -notcontains $path) {
        $blocked += $path
    }
}

if ($blocked.Count -gt 0) {
    Fail "Refusing to publish because unexpected files are modified: $($blocked -join ', ')"
}

Run-Git @("add", "--", "index.html", "fedex-yard-plan.html", "README.md", "AGENTS.md", "scripts/meka-publish.ps1")

$cached = & git diff --cached --name-only
if ($LASTEXITCODE -ne 0) {
    Fail "Could not inspect staged changes."
}

if (-not $cached) {
    if ($AllowNoChanges) {
        Write-Host "No staged changes. Continuing to live verification."
    } else {
        Fail "No publishable changes are staged."
    }
} else {
    Run-Git @("commit", "-m", $Message)
}

$token = $env:MEKA_GITHUB_TOKEN
if ($token) {
    $originalAskPass = $env:GIT_ASKPASS
    $originalTerminalPrompt = $env:GIT_TERMINAL_PROMPT
    $askPass = Join-Path $env:TEMP "meka-git-askpass.ps1"
    Set-Content -Encoding ASCII -Path $askPass -Value @"
param([string]`$prompt)
if (`$prompt -match 'Username') { 'x-access-token' } else { `$env:MEKA_GITHUB_TOKEN }
"@
    $env:GIT_ASKPASS = $askPass
    $env:GIT_TERMINAL_PROMPT = "0"
    try {
        Run-Git @("push", "origin", "main")
    } finally {
        if ($null -eq $originalAskPass) { Remove-Item Env:\GIT_ASKPASS -ErrorAction SilentlyContinue } else { $env:GIT_ASKPASS = $originalAskPass }
        if ($null -eq $originalTerminalPrompt) { Remove-Item Env:\GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue } else { $env:GIT_TERMINAL_PROMPT = $originalTerminalPrompt }
        Remove-Item -LiteralPath $askPass -Force -ErrorAction SilentlyContinue
    }
} else {
    Run-Git @("push", "origin", "main")
}

Write-Host "Pushed main. Checking live site..."

$deadline = (Get-Date).AddMinutes(5)
$cacheBust = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$verified = $false
$lastError = $null

while ((Get-Date) -lt $deadline) {
    try {
        $uri = "$LiveUrl?meka_verify=$cacheBust"
        $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -TimeoutSec 20
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            if ([string]::IsNullOrWhiteSpace($ExpectedText) -or $response.Content.Contains($ExpectedText)) {
                $verified = $true
                break
            }
            $lastError = "Live site loaded, but expected text was not found: $ExpectedText"
        } else {
            $lastError = "Live site returned HTTP $($response.StatusCode)"
        }
    } catch {
        $lastError = $_.Exception.Message
    }
    Start-Sleep -Seconds 15
}

if (-not $verified) {
    Fail "Push completed, but live verification did not pass. Last check: $lastError"
}

Write-Host "Live site verified: $LiveUrl"
