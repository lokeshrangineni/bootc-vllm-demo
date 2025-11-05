#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/serve_openai.sh
#
# Environment variables:
#   VLLM_MODEL  - Hugging Face model id (default: TinyLlama/TinyLlama-1.1B-Chat-v1.0)
#   PORT        - Port to bind (default: 8000)
#   HOST        - Host to bind (default: 127.0.0.1)

MODEL="${VLLM_MODEL:-TinyLlama/TinyLlama-1.1B-Chat-v1.0}"
PORT="${PORT:-8000}"
HOST="${HOST:-127.0.0.1}"

echo "Starting vLLM OpenAI server"
echo "Model : ${MODEL}"
echo "Host  : ${HOST}:${PORT}"
echo

exec python -m vllm.entrypoints.openai.api_server \
  --host "${HOST}" \
  --port "${PORT}" \
  --model "${MODEL}" \
  --dtype float32


