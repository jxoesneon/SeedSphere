param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

if ($Version -notmatch '^\d+\.\d+\.\d+') {
    Write-Error "Invalid version format. Usage: .\release.ps1 -Version 2.0.0"
    exit 1
}

# 1. Update Router
$RouterPubspec = "router/pubspec.yaml"
if (Test-Path $RouterPubspec) {
    $Raw = Get-Content $RouterPubspec -Raw
    $New = $Raw -replace 'version: \d+\.\d+\.\d+.*', "version: $Version"
    Set-Content -Path $RouterPubspec -Value $New -Encoding utf8
    Write-Host "Updated $RouterPubspec to $Version"
    Write-Host "Running dart pub get in router..."
    Push-Location "router"
    dart pub get | Out-Null
    Pop-Location
}

# 2. Update Gardener
$GardenerPubspec = "gardener/pubspec.yaml"
if (Test-Path $GardenerPubspec) {
    $Raw = Get-Content $GardenerPubspec -Raw
    $New = $Raw -replace 'version: \d+\.\d+\.\d+.*', "version: $Version"
    Set-Content -Path $GardenerPubspec -Value $New -Encoding utf8
    Write-Host "Updated $GardenerPubspec to $Version"
    Write-Host "Running flutter pub get in gardener..."
    Push-Location "gardener"
    flutter pub get | Out-Null
    Pop-Location
}

Write-Host "`nRelease v$Version preparation complete!"
