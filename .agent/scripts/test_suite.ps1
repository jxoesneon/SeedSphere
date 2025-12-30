Write-Host " Running SeedSphere Test Suite..." -ForegroundColor Cyan

# 1. Router Tests
Write-Host "`n Testing Router (Dart)..." -ForegroundColor Yellow
Push-Location "router"
try {
    Write-Host "Running dart analyze..."
    dart analyze
    if ($LASTEXITCODE -ne 0) { throw "Router analysis failed" }

    Write-Host "Running dart test..."
    dart test
    if ($LASTEXITCODE -ne 0) { throw "Router tests failed" }
} catch {
    Write-Error $_
    Pop-Location
    exit 1
}
Pop-Location

# 2. Gardener Tests
Write-Host "`n Testing Gardener (Flutter)..." -ForegroundColor Yellow
Push-Location "gardener"
try {
    Write-Host "Running flutter analyze..."
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw "Gardener analysis failed" }

    Write-Host "Running flutter test..."
    flutter test
    if ($LASTEXITCODE -ne 0) { throw "Gardener tests failed" }
} catch {
    Write-Error $_
    Pop-Location
    exit 1
}
Pop-Location

Write-Host "`n All Tests Passed!" -ForegroundColor Green

function Test-Documentation {
    Write-Host "`nTesting Documentation (Linting)..." -ForegroundColor Cyan
    $Errors = 0
    $Files = Get-ChildItem -Path . -Recurse -Filter "*.md" | Where-Object { $_.FullName -notmatch "node_modules|\.git|\.agent" }

    foreach ($File in $Files) {
        $Content = Get-Content $File.FullName
        $LineNum = 0
        foreach ($Line in $Content) {
            $LineNum++
            # MD030: Lists should have 1 space after marker (-  Item)
            if ($Line -match "^-\s{2,}\S") {
                Write-Host "  [FAIL] $($File.Name):$LineNum - MD030: Double space after bullet" -ForegroundColor Red
                $Errors++
            }
        }
    }

    if ($Errors -eq 0) {
        Write-Host "No documentation issues found!" -ForegroundColor Green
    } else {
        Write-Host "Found $Errors documentation issues. Please fix before pushing." -ForegroundColor Yellow
        # Optional: exit 1 to enforce
    }
}

Test-Documentation
