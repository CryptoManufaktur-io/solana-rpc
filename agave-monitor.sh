#!/usr/bin/env bash
set -e
# Adjust to where it is on your system
__ledger_dir=/home/sol/ledger

cd /home/sol
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/agave-validator --ledger ${__ledger_dir} monitor
