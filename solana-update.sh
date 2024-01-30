#!/usr/bin/env bash
# Update Solana without needing to sudo into sol
set -eu

if [ -z "${1:-}" ]; then
  echo "Usage: $0 DESIRED-VERSION"
  exit 0
fi

sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/solana-install init $1
