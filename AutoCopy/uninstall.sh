#!/bin/bash
echo "🗑️  Uninstalling AutoCopy..."
pkill -f "AutoCopy.app" 2>/dev/null && echo "⏹  Stopped." || true
rm -rf "/Applications/AutoCopy.app" && echo "✅ Removed." || echo "ℹ️  Not found."
echo ""; echo "Also remove Accessibility access in System Settings if desired."
