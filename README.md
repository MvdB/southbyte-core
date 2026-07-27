# dgx-spark-core

Shared infrastructure for the DGX Spark model-serving projects. This repo holds
the pieces that are modality-agnostic; the serving/testing stacks live in their
own repos and stay loosely coupled:

| Repo | Scope |
|---|---|
| **dgx-spark-core** (this repo) | HF collection mirror, shared tooling |
| [dgx-spark-vllm](https://github.com/MvdB/dgx-spark-vllm) | Text/vision LLM serving (vLLM) + evaluation testplan |
| dgx-spark-tts *(planned)* | TTS serving + evaluation (NeMo) |
| dgx-spark-image *(planned)* | Text-to-image serving + evaluation (diffusers) |

## Components

### `hf-sync/`

Mirrors a named HuggingFace collection to a local model store using
commit-SHA-based update detection. Formerly `repo-sync/` in dgx-spark-vllm.

```bash
cd hf-sync
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # add your HF_TOKEN
python hf_sync.py
```

Configuration via `.env`:

- `HF_TOKEN` — HuggingFace token (read access is sufficient)
- `HF_COLLECTION` — collection name to sync (default: `LocalCache`)

Model directories are named `<owner>--<model-name>` (HF id with `/` replaced
by `--`); all downstream repos follow this convention.

## Planned

- Shared results schema for cross-modality evaluation reports
- Report/dashboard library (extracted from dgx-spark-vllm/testplan once a
  second modality produces results)
