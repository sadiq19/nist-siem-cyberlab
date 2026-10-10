#!/usr/bin/env bash
# Create repo directories. Does not overwrite existing files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

dirs=(
  docs/01-architecture
  docs/02-compliance-nist
  docs/03-configuration-guide
  docs/04-testing-verification
  docs/05-post-mortem-lessons
  configs/wazuh
  configs/endpoints
  configs/network
  scripts
  assets/diagrams
  assets/screenshots/01-raw-logs
  assets/screenshots/02-alerts
  assets/screenshots/03-dashboards
  assets/sprint-1
  assets/sprint-2
  assets/sprint-3
  assets/sprint-4
  assets/sprint-5
  assets/sprint-6
  assets/sprint-7
  assets/sprint-8
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

placeholders=(
  assets/diagrams/.gitkeep
  assets/screenshots/01-raw-logs/.gitkeep
  assets/screenshots/02-alerts/.gitkeep
  assets/screenshots/03-dashboards/.gitkeep
  assets/sprint-1/.gitkeep
  assets/sprint-2/.gitkeep
  assets/sprint-3/.gitkeep
  assets/sprint-4/.gitkeep
  assets/sprint-5/.gitkeep
  assets/sprint-6/.gitkeep
  assets/sprint-7/.gitkeep
  assets/sprint-8/.gitkeep
)

for f in "${placeholders[@]}"; do
  if [[ ! -e "$f" ]]; then
    : > "$f"
  fi
done

echo "Directory layout ready under $ROOT"
echo "Run: bash scripts/validate_configs.sh"
