#!/bin/bash
echo "=== LiteLLM Gateway Status ==="
if [ -f "litellm.pid" ]; then
  PID=$(cat litellm.pid)
  if kill -0 "$PID" 2>/dev/null; then
    echo "Running (PID $PID)"
  else
    echo "PID file exists but process not running."
  fi
else
  echo "Not running."
fi

echo ""
echo "Checking endpoint..."
curl -s http://localhost:4000/v1/models || echo "No response"
