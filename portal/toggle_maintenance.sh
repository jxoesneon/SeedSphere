#!/bin/bash

# A script to toggle the portal between Maintenance Mode and Normal Operation.
# Usage: ./toggle_maintenance.sh [on|off]

MODE=$1

if [ "$MODE" == "on" ]; then
    echo "🌱 Enabling Maintenance Mode..."
    if [ -f "maintenance.html" ]; then
        cp maintenance.html index.html
        echo "✅ System is now UNDER MAINTENANCE."
    else
        echo "❌ Error: maintenance.html not found."
        exit 1
    fi
elif [ "$MODE" == "off" ]; then
    echo "🌍 restoring Normal Operation..."
    if [ -f "home.html" ]; then
        cp home.html index.html
        echo "✅ System is now ONLINE."
    else
        echo "❌ Error: home.html not found."
        exit 1
    fi
else
    echo "Usage: ./toggle_maintenance.sh [on|off]"
    echo "  on  - Activate maintenance page"
    echo "  off - Restore original site (from backup)"
    exit 1
fi
