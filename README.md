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
| [southbyte-image](https://github.com/MvdB/southbyte-image) | Text-to-image serving + evaluation (diffusers) |
| [southbyte-music](https://github.com/MvdB/southbyte-music) | Text-to-music serving (MiniMax-Music3 via SGLang-Omni) + web interface, Helm chart |
| [southbyte-results](https://github.com/MvdB/southbyte-results) | Cross-modality results website → [mvdb.github.io/southbyte-results](https://mvdb.github.io/southbyte-results/) |

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

- An evaluation harness for `southbyte-music`. Every other stack measures its
  models — WER for TTS, prompt fidelity for image, judge-scored playbooks for
  LLMs. Music has no metric yet; what sounds good is decided by ear for now.
- Shared results schema for cross-modality evaluation reports (the curated
  aggregation already lives in [southbyte-results](https://github.com/MvdB/southbyte-results))

---

Built by [southbyte](https://southbyte.de).
