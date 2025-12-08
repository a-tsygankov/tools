#!/bin/bash
set -e
if [ -f "litellm.pid" ]; then
  PID=$(cat litellm.pid)
  echo "Stopping PID $PID"
  kill "$PID" || true
  rm litellm.pid
else
  echo "Not running."
fi
rm -f logs/*.log
echo "Stopped."
