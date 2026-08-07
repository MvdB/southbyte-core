#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
.venv-linux/bin/python hf_sync.py "$@"
