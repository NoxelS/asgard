# Llama

Local `llama.cpp` server for CPU inference.

## Overview

This service serves local GGUF models over HTTP for host tools and other Docker containers.

## Access

- Docker network: `http://llama:8080`
- Public route: `https://llm.noel.fyi` through Caddy bearer-token auth
- Model list: `GET /v1/models`

## Configuration

- `MODEL_DIR` - Host path that contains GGUF model files
- `MODELS_MAX` - Maximum models the llama.cpp router may load simultaneously
- `CONTEXT_SIZE` - Prompt/context window
- `PARALLEL_REQUESTS` - Concurrent requests
- `THREADS` - CPU threads to use
- `N_PREDICT` - Maximum generated tokens per request

## Install Model

The container expects GGUF files under `${MODEL_DIR}`. The llama.cpp router scans this directory and exposes the available models via `/v1/models`.

Example:

```bash
sudo mkdir -p /srv/models/llama
cd /srv/models/llama
```

If you already have GGUF files, copy them into `MODEL_DIR`.

If the model is on Hugging Face, download it directly with `huggingface-cli`:

```bash
huggingface-cli download <repo-id> <file-name.gguf> --local-dir /srv/models/llama --local-dir-use-symlinks False
```

If you only have a non-GGUF checkpoint, it must be converted to GGUF before `llama.cpp` can serve it.

## Notes

- It connects to the shared `apps` network so Caddy and future services can reach it.
- `MODELS_MAX=1` keeps memory use bounded while still allowing the router to list all GGUF files.
- `Phi-3.5-MoE-Instruct` with `Q6_K` may be tight for 8 GB RAM; reduce context or quantization if it OOMs.
