#!/bin/bash
PIDFILE="litellm.pid"
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "{"running": true, "pid": $PID}"
    exit 0
  fi
fi
echo "{"running": false}"
