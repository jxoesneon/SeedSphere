param(
    [string]$BaseRef = "origin/main",
    [string]$HeadRef = "HEAD"
)

# Function to check if path matches pattern
function Test-Match {
    param($Files, $Pattern)
    return ($Files | Where-Object { $_ -match $Pattern }).Count -gt 0
}

try {
    # Get changed files
    # Try exact match first
    if (git rev-parse --verify $BaseRef 2>$null) {
        $Diff = git diff --name-only $BaseRef...$HeadRef
    } elseif (git rev-parse --verify "origin/$BaseRef" 2>$null) {
        # Fallback to origin/BaseRef if local not found
        $Diff = git diff --name-only "origin/$BaseRef...$HeadRef"
    } else {
        # Fallback to direct diff if merge base fails
        $Diff = git diff --name-only $BaseRef $HeadRef
    }
} catch {
    Write-Warning "Could not determine diff. defaulting to full build."
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
        cmd = "flutter test"
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

# Always include functional tests if anything changed? 
# For now, strictly modular.

# If nothing matched (e.g. only README), output empty matrix or specific "skip" job?
# GitHub Actions fails on empty matrix. We should handle this in workflow, or output a dummy "skip"
if ($Matrix.include.Count -eq 0) {
    # Optional: logic to skip
    Write-Host "{""include"":[]}"
} else {
    $Matrix | ConvertTo-Json -Depth 5 -Compress
}
