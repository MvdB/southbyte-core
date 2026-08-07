# southbyte-core

Shared index and cross-cutting infrastructure for the **southbyte** DGX Spark
model-serving family. The frameworks are hardware-agnostic and stay loosely
coupled in their own repos; the one genuinely GB10-specific piece (tuned serving
profiles) is isolated in its own repo too.

| Repo | Scope |
|---|---|
| **southbyte-core** (this repo) | Shared index; cross-modality results schema + dashboard lib *(planned)* |
| [southbyte-sync](https://github.com/MvdB/southbyte-sync) | HuggingFace collection mirror → local model store; defines the `<owner>--<model-name>` naming |
| [southbyte-vllm](https://github.com/MvdB/southbyte-vllm) | vLLM serving runner + LLM evaluation testplan |
| [southbyte-tts](https://github.com/MvdB/southbyte-tts) | TTS/STT serving + German-language evaluation |
| [southbyte-spark-profiles](https://github.com/MvdB/southbyte-spark-profiles) | DGX Spark (GB10) validated vLLM + vLLM-omni profiles, custom kernels, benchmarks |
| southbyte-image *(planned)* | Text-to-image serving + evaluation (diffusers) |

## How the family fits together

- **Model store** — all stacks read models from `~/hf_models/`, which is a working
  clone of [southbyte-sync](https://github.com/MvdB/southbyte-sync) (the models are
  downloaded into the tool's own tree). That repo owns the `<owner>--<model-name>`
  directory convention every other repo follows.
- **Hardware tuning** — `southbyte-vllm` and `southbyte-tts` are GB10-agnostic; they
  read their Spark-validated profiles from `southbyte-spark-profiles`. Swap that repo
  to target different hardware without touching the frameworks.
- **Collection sync is not vendored here.** It previously lived as a copy in this
  repo (`hf-sync/`, itself formerly `repo-sync/` in the vllm repo); that duplicate
  was removed in favour of the standalone `southbyte-sync`.

## Planned

- **`southbyte-image`** — text-to-image serving + evaluation (diffusers), following
  the same curated-profile + evaluation pattern as the vLLM and TTS stacks; its
  GB10-tuned profiles will live in `southbyte-spark-profiles/image/`
- Shared results schema for cross-modality evaluation reports
- Report/dashboard library (extracted from `southbyte-vllm/testplan` once a second
  modality produces results)

---

Built by [southbyte](https://southbyte.de).
