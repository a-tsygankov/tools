#!/bin/bash
set -e
echo "=== LiteLLM Setup ==="
if ! command -v python3 >/dev/null; then
  echo "Installing python via Homebrew..."
  brew install python
fi
mkdir -p logs
if [ ! -d "litellm-venv" ]; then python3 -m venv litellm-venv; fi
source litellm-venv/bin/activate
pip install --upgrade pip
pip install "litellm[proxy]"
echo "Install complete. Run ./start-gui.sh to configure."
