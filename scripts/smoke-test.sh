#!/usr/bin/env bash
# Readiness checks on an approved GPU deployment. Optional inference is explicit.
set -euo pipefail
sudo test -f /var/lib/ai-dev-box/ready
systemctl is-active --quiet ollama
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
curl --fail --silent --show-error http://127.0.0.1:11434/api/version | jq -e .version
opencode --version
if [[ $# -gt 0 ]]; then
  payload=$(jq -n --arg model "$1" '{model: $model, stream: false, messages: [{role: "user", content: "Reply with the single word READY."}], options: {num_predict: 32}}')
  curl --fail --silent --show-error --max-time 180 \
    http://127.0.0.1:11434/api/chat -H 'Content-Type: application/json' \
    --data "$payload" | jq -e '.message.content | select(length > 0)'
  ollama ps
  echo "Confirm GPU residency in ollama ps; this is not an agent/tool-use benchmark."
fi
