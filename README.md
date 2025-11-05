## vLLM CPU demo (macOS M3)

This repo contains a minimal, CPU-only vLLM demo suitable for a MacBook Pro (M3). It lets you:
- Run a quick generation from a small model
- Start the OpenAI-compatible server and call it via curl

### Prerequisites
- Conda environment with Python 3.10+ and `vllm` installed 
- Internet access on first run to download the model from Hugging Face


### Run the OpenAI-compatible server (CPU)
```bash
conda activate vllm-bootc-demo

# Optional overrides
# export VLLM_MODEL="TinyLlama/TinyLlama-1.1B-Chat-v1.0"
# export PORT=8000

bash scripts/serve_openai.sh
```

Then test with curl in another terminal:
```bash
curl -s http://127.0.0.1:${PORT:-8000}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${VLLM_MODEL:-TinyLlama/TinyLlama-1.1B-Chat-v1.0}"'",
    "messages": [
      {"role": "system", "content": "Answer concisely and stay on topic."},
      {"role": "user", "content": "Give me three fun facts about penguins."}
    ],
    "temperature": 0.2,
    "max_tokens": 200
  }' | jq '.'
```

TinyLlama is kept as the default to work on lower-resource systems.
### Notes
- This runs on CPU. Performance is limited compared to NVIDIA GPUs.
- First run will download model weights to your local Hugging Face cache.
- If you hit installation/runtime issues on macOS, try a smaller model or run on a CUDA-enabled Linux machine for best performance.

### Hugging Face token (optional)
- Public models (like TinyLlama) do not require a token. Gated/private models do.
- Provide a token via env or login:
  ```bash
  export HUGGING_FACE_HUB_TOKEN=hf_xxx   # or HF_TOKEN
  # or
  huggingface-cli login --token hf_xxx
  ```

## Bootc image (vLLM-only)

This repo includes a bootc `Containerfile` to build a bootable image that auto-starts the vLLM OpenAI-compatible server on boot.

### Project structure
```
bootc-vllm-demo/
  bootc/
    start-vllm.sh        # boot-time entrypoint for vLLM server
    vllm.service         # systemd unit
  scripts/
    serve_openai.sh      # run server locally (OpenAI-compatible)
    build_bootc_qcow2.sh # build bootable qcow2 via bootc-image-builder
  artifacts/             # qcow2 outputs (ignored by git)
  Containerfile.bootc    # bootc OS image definition
  README.md
```

Files:
- `Containerfile.bootc`: bootc OS image with Python + vLLM.
- `bootc/start-vllm.sh`: startup script reading env vars and launching the server.
- `bootc/vllm.service`: systemd unit enabling the service at boot.

Default server settings (overridable at boot/runtime via env):
- `VLLM_MODEL=TinyLlama/TinyLlama-1.1B-Chat-v1.0`
- `HOST=0.0.0.0`
- `PORT=8000`
- `DTYPE=float32`
- `VLLM_EXTRA_ARGS` (free-form flags passed to `api_server`)

Build the bootc image (example):
```bash
podman build -f Containerfile.bootc -t quay.io/lrangine/vllm-bootc-demo:1.0.0 .
```

Install or run depends on your target (bare metal, VM, etc.). Refer to bootc docs for `bootc install to-disk` and related flows. On first boot, the service starts automatically and binds `${HOST}:${PORT}`.

Test after boot (from another host):
```bash
curl -s http://<node-ip>:8000/v1/models | jq '.'

curl -s http://<node-ip>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${VLLM_MODEL:-TinyLlama/TinyLlama-1.1B-Chat-v1.0}"'",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Say hello from a bootc image."}
    ],
    "max_tokens": 64
  }' | jq '.'
```

Notes:
- CPU-first: works anywhere; performance on GPU requires host NVIDIA drivers and container runtime GPU support when applicable. Device selection is autodetected by vLLM (no `--device` flag in this version).
- For OpenShift GPU nodes, use a GPU-capable container (not a bootc OS) with the same `vllm.entrypoints.openai.api_server` command and NVIDIA runtime; API remains the same.

### Build a bootable VM image with bootc-image-builder (qcow2)

Prereqs:
- Podman with privileged containers enabled (Podman Desktop or podman machine on macOS)
- Ensure Podman VM is rootful (builder requires it):
  ```bash
  podman machine stop
  podman machine set --rootful
  podman machine start
  ```

Build qcow2 from the local image:
```bash
podman build -f Containerfile.bootc -t localhost/vllm-bootc:latest .

# Build qcow2 (x86_64 default)
bash scripts/build_bootc_qcow2.sh

# Build qcow2 for Apple Silicon (ARM/M3)
ARCH=aarch64 OUT_DIR=artifacts bash scripts/build_bootc_qcow2.sh
```

The output appears under `artifacts/qcow2/disk.qcow2`.

Quick QEMU test (x86_64):
```bash
qemu-system-x86_64 -m 4096 -smp 2 -cpu host \
  -drive if=virtio,file=artifacts/qcow2/disk.qcow2 \
  -netdev user,id=net0,hostfwd=tcp::8000-:8000 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

Quick QEMU test (aarch64, macOS HVF, >= 4 GB RAM)
```bash
qemu-system-aarch64 -accel hvf -cpu host \
  -machine virt,highmem=on,gic-version=3 \
  -m 8192 -smp 4 \
  -drive if=virtio,format=qcow2,file=artifacts/qcow2/disk.qcow2 \
  -netdev user,id=net0,hostfwd=tcp::8000-:8000 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

Once booted, the vLLM service will start automatically. From the host:
```bash
curl -s http://127.0.0.1:8000/v1/models | jq '.'
```

Chat completion (on-topic, concise)
```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "messages": [
      {"role": "system", "content": "You are a concise assistant about vLLM."},
      {"role": "user", "content": "What is vLLM used for?"}
    ],
    "temperature": 0.2,
    "max_tokens": 200
  }' | jq '.'
```

Prompt-style completion (non-chat endpoint)
```bash
curl -s http://127.0.0.1:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "prompt": "Summarize vLLM in one sentence.",
    "temperature": 0.2,
    "max_tokens": 80
  }' | jq '.'
```

Streaming chat completion (Server-Sent Events)
```bash
curl -N http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "messages": [
      {"role": "system", "content": "Stream your answer chunk by chunk."},
      {"role": "user", "content": "Name three uses of vLLM."}
    ],
    "stream": true,
    "temperature": 0.2,
    "max_tokens": 120
  }'
```

### Troubleshooting
- Builder complains about rootless: switch the Podman VM to rootful (see above) and rebuild.
- Builder can’t access container storage: ensure the script ran under rootful Podman; it mounts `/var/lib/containers/storage` inside the builder.
- QEMU aarch64 “Addressing limited to 32 bits…”: use `-machine virt,highmem=on,gic-version=3` (example above) or reduce RAM to ≤ 3 GB.
- Empty/irrelevant model responses: small models can hallucinate. Use a tighter system prompt, lower temperature, or a stronger model.


