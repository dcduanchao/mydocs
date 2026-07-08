#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="/var/www/html/mydocs"
CONDA_ENV="mkdocs"
CONDA_BIN="/root/miniconda3/bin/conda"

export PATH="/root/miniconda3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

cd "$PROJECT_DIR"

if [[ ! -f "mkdocs.yml" ]]; then
    echo "Error: mkdocs.yml not found in $PROJECT_DIR" >&2
    exit 1
fi

if [[ ! -x "$CONDA_BIN" ]]; then
    echo "Error: conda not found at $CONDA_BIN" >&2
    exit 1
fi

echo "[1/4] Pull latest code"
git pull --ff-only origin main

echo "[2/4] Build MkDocs site"
"$CONDA_BIN" run -n "$CONDA_ENV" mkdocs build

echo "[3/4] Sync site to nginx directory"
mkdir -p "$DEPLOY_DIR"
rsync -av --delete "$PROJECT_DIR/site/" "$DEPLOY_DIR/"

echo "[4/4] Done"
echo "Preview: http://mydocs.du-ai.top/"
