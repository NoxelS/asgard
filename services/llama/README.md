# Llama

Local `llama.cpp` server for CPU inference.

## Overview

This service serves a local GGUF model over HTTP for host tools and other Docker containers.

## Access

- Docker network: `http://llama:8080`

## Configuration

- `MODEL_DIR` - Host path that contains the GGUF model file
- `MODEL_FILE` - GGUF filename inside `MODEL_DIR`
- `CONTEXT_SIZE` - Prompt/context window
- `PARALLEL_REQUESTS` - Concurrent requests
- `THREADS` - CPU threads to use
- `N_PREDICT` - Maximum generated tokens per request

## Install Model

The container expects a GGUF file on the host at `${MODEL_DIR}/${MODEL_FILE}`.

Example:

```bash
sudo mkdir -p /srv/models/llama
cd /srv/models/llama
```

If you already have the GGUF file, copy it there and make sure the filename matches `MODEL_FILE`.

If the model is on Hugging Face, download it directly with `huggingface-cli`:

```bash
huggingface-cli download <repo-id> <file-name.gguf> --local-dir /srv/models/llama --local-dir-use-symlinks False
```

Then set `MODEL_FILE` in `.env` to the downloaded filename.

If you only have a non-GGUF checkpoint, it must be converted to GGUF before `llama.cpp` can serve it.

## Notes

- This service is internal only and does not use Caddy.
- It connects to the shared `apps` network so future services can reach it.
- `Phi-3.5-MoE-Instruct` with `Q6_K` may be tight for 8 GB RAM; reduce context or quantization if it OOMs.
