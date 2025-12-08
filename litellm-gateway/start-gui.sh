#!/bin/bash
set -e
if [ ! -d "litellm-venv" ]; then echo "Run ./install.sh first."; exit 1; fi
source litellm-venv/bin/activate

echo "Select model:
1) gpt-4o-mini
2) gpt-4o
3) gpt-4.1
4) gpt-4.1-mini
5) Custom"

read -p "Choice: " c
case $c in
 1) MODEL="gpt-4o-mini";;
 2) MODEL="gpt-4o";;
 3) MODEL="gpt-4.1";;
 4) MODEL="gpt-4.1-mini";;
 5) read -p "Enter custom model: " MODEL;;
 *) echo "Invalid"; exit 1;;
esac

read -s -p "Enter API key (sk-...): " KEY; echo
if [ -z "$KEY" ]; then echo "Key empty"; exit 1; fi

cat > config.yaml <<EOF
model_list:
  - model_name: "${MODEL}"
    litellm_params:
      model: "${MODEL}"
      api_key: "${KEY}"
      api_base: "https://api.openai.com/v1"
port: 4000
EOF

echo "Saved config.yaml. Run ./start.sh"
