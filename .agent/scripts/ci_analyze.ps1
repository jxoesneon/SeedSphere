param(
    [string]$BaseRef = "origin/main",
    [string]$HeadRef = "HEAD"
)

# Enforce bounded regex for input validation (Security Mandate)
# Prevents leading hyphens and limits length to 127 chars
$RefRegex = '^[A-Za-z0-9_./][A-Za-z0-9_./-]{0,127}$'

if (-not ($BaseRef -match $RefRegex) -or -not ($HeadRef -match $RefRegex)) {
    Write-Error "Invalid Git Reference: Potential Injection Attempt Detected."
    exit 1
}

# Function to check if path matches pattern
function Test-Match {
    param($Files, $Pattern)
    return ($Files | Where-Object { $_ -match $Pattern }).Count -gt 0
}
...
try {
    # Try exact match first
    Write-Host "Verifying BaseRef: $BaseRef"
    if (git rev-parse --verify "$BaseRef" 2>$null) {
        Write-Host "BaseRef found. Diffing $BaseRef...$HeadRef"
        $Diff = git diff --name-only "$BaseRef...$HeadRef"
    } elseif (git rev-parse --verify "origin/$BaseRef" 2>$null) {
        Write-Host "Fallback to origin/$BaseRef. Diffing origin/$BaseRef...$HeadRef"
        $Diff = git diff --name-only "origin/$BaseRef...$HeadRef"
    } else {
        Write-Host "BaseRef not found. Direct diff $BaseRef $HeadRef"
        $Diff = git diff --name-only "$BaseRef" "$HeadRef"
    }
} catch {
    Write-Warning "Git error: $_"
    Write-Warning "Defaulting to full build."
    $Diff = @("gardener/", "router/")
}

$Matrix = @{
    include = @()
}

# Analyze Gardener
if (Test-Match $Diff "^gardener/") {
    $Matrix.include += @{
        project = "gardener"
        os = "ubuntu-latest"
        cmd = "flutter test --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET"
    }
}

# Analyze Router
if (Test-Match $Diff "^router/") {
    $Matrix.include += @{
        project = "router"
        os = "ubuntu-latest"
        cmd = "dart test"
    }
}

# Analyze Bridge
if (Test-Match $Diff "^bridge/") {
    $Matrix.include += @{
        project = "bridge"
        os = "ubuntu-latest"
        cmd = "npm run build"
    }
}

# Analyze Legacy
if (Test-Match $Diff "^legacy/") {
    $Matrix.include += @{
        project = "legacy"
        os = "ubuntu-latest"
        cmd = "npm test"
    }
}

# Always include functional tests if anything changed? 
# For now, strictly modular.

# If nothing matched (e.g. only README), output empty matrix or specific "skip" job?
# GitHub Actions fails on empty matrix. We should handle this in workflow, or output a dummy "skip"
if ($Matrix.include.Count -eq 0) {
    # Optional: logic to skip
    Write-Output "{""include"":[]}"
} else {
    $Matrix | ConvertTo-Json -Depth 5 -Compress
}
