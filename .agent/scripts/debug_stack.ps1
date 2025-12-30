# .agent/scripts/debug_stack.ps1
# Script to run SeedSphere Full Stack (Router + Portal) and filter for errors
# Usage: ./debug_stack.ps1

$baseDir = Get-Location
$routerPath = Join-Path $baseDir "router"
$portalPath = Join-Path $baseDir "portal"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   SEEDSPHERE FULL STACK DEBUGGER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Router Path: $routerPath" -ForegroundColor Gray
Write-Host "Portal Path: $portalPath" -ForegroundColor Gray
Write-Host "Starting services... Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

# Function to filter output line-by-line
function Filter-Output {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$Line,
        [string]$Prefix
    )
    process {
        # Reduce noise: Ignore mDNS errors
        if ($Line -match "MDNSHandler|mDNS hostname") {
            return
        }

        if ($Line -match "Error|Exception|Fail|Severe|Stack trace|WARN") {
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] [$Prefix] $Line" -ForegroundColor Red
        } elseif ($Line -match "listening|Available on") {
            # Always show startup success messages
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] [$Prefix] $Line" -ForegroundColor Green
        }
    }
}

# Cleanup existing processes
Write-Host "Killing stale processes..." -ForegroundColor DarkGray
Stop-Process -Name "dart" -ErrorAction SilentlyContinue
Stop-Process -Name "node" -ErrorAction SilentlyContinue

# Start Jobs
$routerJob = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    # Redirect stderr to stdout to capture everything
    dart run bin/server.dart 2>&1
} -ArgumentList $routerPath

$portalJob = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    # Run http-server on port 8081
    npx http-server . -p 8081 -c-1 2>&1
} -ArgumentList $portalPath

try {
    while ($true) {
        # Check Router Output
        $rOut = $routerJob | Receive-Job
        if ($rOut) {
            $rOut | ForEach-Object { Filter-Output -Line $_ -Prefix "ROUTER" }
        }

        # Check Portal Output
        $pOut = $portalJob | Receive-Job
        if ($pOut) {
            $pOut | ForEach-Object { Filter-Output -Line $_ -Prefix "PORTAL" }
        }

        Start-Sleep -Milliseconds 500
    }
} finally {
    Write-Host "`nStopping services..." -ForegroundColor Yellow
    Stop-Job $routerJob
    Stop-Job $portalJob
    Remove-Job $routerJob
    Remove-Job $portalJob
    Write-Host "Done." -ForegroundColor Cyan
}
