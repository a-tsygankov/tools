#!/bin/bash
set -e
if [ ! -d "litellm-venv" ]; then echo "Run ./install.sh first."; exit 1; fi
if [ ! -f "config.yaml" ]; then echo "Run ./start-gui.sh first."; exit 1; fi

source litellm-venv/bin/activate

if [ -f "litellm.pid" ]; then
  PID=$(cat litellm.pid)
  if kill -0 "$PID" 2>/dev/null; then
    echo "Stopping previous (PID $PID)"
    kill "$PID" || true
    sleep 1
  fi
  rm litellm.pid
fi

litellm --config config.yaml > logs/litellm.log 2>&1 &
echo $! > litellm.pid
echo "Gateway started http://localhost:4000/v1"
