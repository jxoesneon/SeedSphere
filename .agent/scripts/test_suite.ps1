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
