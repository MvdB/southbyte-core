# dgx-spark-core

Shared infrastructure for the DGX Spark model-serving projects. This repo holds
the pieces that are modality-agnostic; the serving/testing stacks live in their
own repos and stay loosely coupled:

| Repo | Scope |
|---|---|
| **dgx-spark-core** (this repo) | HF collection mirror, shared tooling |
| [dgx-spark-vllm](https://github.com/MvdB/dgx-spark-vllm) | Text/vision LLM serving (vLLM) + evaluation testplan |
| [dgx-spark-tts](https://github.com/MvdB/dgx-spark-tts) | TTS serving + German-language evaluation (NeMo, Qwen3-TTS) |
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

Per-model file filtering: `ALLOW_PATTERNS` in `hf_sync.py` restricts a download
to specific files (e.g. one quantisation variant instead of a whole multi-hundred-GB
repo). A pattern change is tracked in `.sync_state.json` alongside the commit SHA,
so editing the patterns re-triggers a sync even when the remote SHA is unchanged.

#### Deployment / runtime layout

`hf_sync.py` is the source of truth here, but it runs from the **model store**
(`~/hf_models/`), not from this repo — the venv (`.venv-linux/`), `.env`, and
`.sync_state.json` live next to the downloaded models. The store therefore holds
deployed copies of `hf_sync.py` + `hf_sync.sh`; after editing here, redeploy with:

```bash
cp hf-sync/hf_sync.py hf-sync/hf_sync.sh ~/hf_models/
```

Runtime wrappers, all tracked here as the reference copies:

- `hf_sync.sh` — Linux launcher (`cd $(dirname $0) && .venv-linux/bin/python hf_sync.py`)
- `hf_sync.bat` — Windows launcher equivalent
- `sync_nas.sh` — pull the collection from the NAS mirror (`/nfs/ai/hf_models/`)
- `sync_all.sh` — **hourly-cron orchestrator**: HF→local sync, then local→NAS push,
  then retention (moves non-collection models to `/nfs/ai/old_models`, never deletes).
  Config block at the top is machine-specific. Installed via
  `0 * * * * ~/dgx-spark/dgx-spark-core/hf-sync/sync_all.sh`.

## Planned

- Shared results schema for cross-modality evaluation reports
- Report/dashboard library (extracted from dgx-spark-vllm/testplan once a
  second modality produces results)
