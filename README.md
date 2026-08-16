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
| [southbyte-results](https://github.com/MvdB/southbyte-results) | Cross-modality results → website [results.southbyte.de](https://results.southbyte.de/) + dataset [SouthByte/dgx-spark-eval](https://huggingface.co/datasets/SouthByte/dgx-spark-eval) |

## How the family fits together

- **Model store** — all stacks read models from `~/hf_models/`, which is a working
  clone of [southbyte-sync](https://github.com/MvdB/southbyte-sync) (the models are
  downloaded into the tool's own tree). That repo owns the `<owner>--<model-name>`
  directory convention every other repo follows.
- **Hardware tuning** — `southbyte-vllm` and `southbyte-tts` are GB10-agnostic; they
  read their Spark-validated profiles from `southbyte-spark-profiles`. Swap that repo
  to target different hardware without touching the frameworks.
- **Results** — each stack writes its own result feeds locally. `southbyte-results`
  normalises them once and emits two things from that single source, so they cannot
  drift apart: the website above and the Hugging Face dataset
  [SouthByte/dgx-spark-eval](https://huggingface.co/datasets/SouthByte/dgx-spark-eval)
  (73 measurement runs in five configs, CC BY 4.0). Curated metrics only — the
  security playbook and all raw transcripts stay on the machine. One run per model,
  one judge, one machine: useful as an order of magnitude, not as a benchmark.
- **Collection sync is not vendored here.** It previously lived as a copy in this
  repo (`hf-sync/`, itself formerly `repo-sync/` in the vllm repo); that duplicate
  was removed in favour of the standalone `southbyte-sync`.

## Planned

- A per-model evaluation for `southbyte-music`. Every other stack measures its
  models — WER for TTS, prompt fidelity for image, judge-scored playbooks for
  LLMs. Music has instrumented measurements now (tempo, stereo width, crest
  factor, energy arc; `eval/caption-ab/`), but they were built to compare two
  caption formats, not two models, and they are not in the dataset yet.
- A shared schema for the result feeds themselves. The published side is
  settled — [SouthByte/dgx-spark-eval](https://huggingface.co/datasets/SouthByte/dgx-spark-eval)
  fixes the columns for all five configs — but upstream every stack still
  writes its own report format, and `southbyte-results` absorbs the differences.

---

Built by [southbyte](https://southbyte.de).
