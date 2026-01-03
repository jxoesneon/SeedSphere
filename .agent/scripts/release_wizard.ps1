param(
    [string]$Version
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   SeedSphere Release Wizard 🧙‍♂️" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Version Input
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Read-Host "Enter Target Version (e.g. 1.9.7)"
}

if ($Version -notmatch '^\d+\.\d+\.\d+') {
    Write-Error "Invalid version format '$Version'. Expected X.Y.Z (e.g. 1.9.7)"
    exit 1
}

Write-Host "`nTarget Release: v$Version" -ForegroundColor Green

# 2. Verification Phase
Write-Host "`n[Phase 1] Verification" -ForegroundColor Yellow
$RunTests = Read-Host "Run Test Suite? (Y/n)"
if ($RunTests -ne "n") {
    Write-Host "Running tests..."
    try {
        & "$PSScriptRoot/test_suite.ps1"
        if ($LASTEXITCODE -ne 0) { throw "Tests Failed" }
        Write-Host "Tests Passed!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Tests Reporting Failure." -ForegroundColor Red
        $Decision = Read-Host "Do you want to (A)bort, (R)etry, or (F)orce Continue?"
        switch ($Decision.ToUpper()) {
            "R" { & "$PSScriptRoot/release_wizard.ps1" -Version $Version; exit }
            "F" { Write-Host "⚠️  Forcing Release (Bypassing Tests)" -ForegroundColor Yellow }
            Default { Write-Error "Aborted by user."; exit 1 }
        }
    }
} else {
    Write-Host "⚠️  Skipping Verification." -ForegroundColor Yellow
}

# 3. Execution Phase
Write-Host "`n[Phase 2] Update Codebase" -ForegroundColor Yellow

$Updated = @()

# Router
$RouterPubspec = "$PSScriptRoot/../../router/pubspec.yaml"
if (Test-Path $RouterPubspec) {
    $Raw = Get-Content $RouterPubspec -Raw
    if ($Raw -match "version: $Version") {
        Write-Host "Router already at v$Version" -ForegroundColor Gray
    } else {
        Write-Host "Bumping Router to v$Version..."
        $New = $Raw -replace 'version: \d+\.\d+\.\d+.*', "version: $Version"
        Set-Content -Path $RouterPubspec -Value $New -Encoding utf8
        $Updated += "router/pubspec.yaml"
        
        Write-Host "Running dart pub get..."
        Push-Location "$PSScriptRoot/../../router"
        dart pub get | Out-Null
        Pop-Location
    }
}

# Gardener
$GardenerPubspec = "$PSScriptRoot/../../gardener/pubspec.yaml"
if (Test-Path $GardenerPubspec) {
    # Gardener often has build numbers (e.g., +196). We preserve them or user needs to supply them.
    # For simplification, we just split.
    $CurrentRaw = Get-Content $GardenerPubspec -Raw
    
    Write-Host "Bumping Gardener to v$Version..."
    # Dynamic Versioning Policy: We explicitly STRIP existing build numbers (e.g. +123)
    # because CI/CD pipelines (GitHub Actions) inject the build number dynamically.
    # We do NOT want hardcoded build numbers in the repo.
    $New = $CurrentRaw -replace 'version: \d+\.\d+\.\d+.*', "version: $Version"
    Write-Host "  -> Set to $Version (Build number stripped for dynamic CI)" -ForegroundColor Cyan
    Set-Content -Path $GardenerPubspec -Value $New -Encoding utf8
    $Updated += "gardener/pubspec.yaml"
    
    Write-Host "Running flutter pub get..."
    Push-Location "$PSScriptRoot/../../gardener"
    flutter pub get | Out-Null
    Pop-Location
}

# 4. Git Operations
Write-Host "`n[Phase 3] Git Operations" -ForegroundColor Yellow
$GitStatus = git status --porcelain
if ([string]::IsNullOrWhiteSpace($GitStatus)) {
    Write-Host "No changes to commit." -ForegroundColor Gray
} else {
    Write-Host "Pending Changes:"
    $GitStatus
    
    $Commit = Read-Host "Stage and Commit these changes for v$Version? (Y/n)"
    if ($Commit -ne "n") {
        git add .
        git commit -m "chore(release): bump version to $Version [skip ci]"
        Write-Host "Committed." -ForegroundColor Green
    }
}

# Tagging
$Tag = "v$Version"
$ExistingTag = git tag -l $Tag
if ($ExistingTag) {
    Write-Host "Tag $Tag already exists." -ForegroundColor Red
    $Retag = Read-Host "Delete and recreate tag? (y/N)"
    if ($Retag -eq "y") {
        git tag -d $Tag
        git tag $Tag
        Write-Host "Re-tagged $Tag" -ForegroundColor Green
    }
} else {
    $DoTag = Read-Host "Create tag $Tag? (Y/n)"
    if ($DoTag -ne "n") {
        git tag $Tag
        Write-Host "Tagged $Tag" -ForegroundColor Green
    }
}

# Push
Write-Host "`n[Phase 4] Deployment" -ForegroundColor Yellow
$Push = Read-Host "Push branch and tags to Origin? (y/N)"
if ($Push -eq "y") {
    Write-Host "Pushing..."
    git push origin main
    git push origin $Tag
    Write-Host "🚀 Release Pushed!" -ForegroundColor Green
} else {
    Write-Host "Done. Remember to push later." -ForegroundColor Gray
}
