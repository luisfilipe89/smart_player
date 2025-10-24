#!/bin/bash
# Flutter Monitor Helper
# Usage: ./flutter-monitor.sh run [other flutter commands]

LOGFILE="/tmp/flutter_output_$(date +%Y%m%d_%H%M%S).log"
echo "$LOGFILE" > /tmp/flutter_current_log.txt

echo "🔍 Monitoring Flutter output: $LOGFILE"
echo "Ask Cursor AI: 'check for issues' anytime!"
echo ""

flutter "$@" 2>&1 | tee "$LOGFILE"
