#!/usr/bin/env bash
# Start this playground's services. Extra args go to `docker compose up`.
set -euo pipefail
cd "$(dirname "$0")"
docker compose up -d "$@"
