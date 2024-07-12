#!/usr/bin/env bash
# Safely restart Solana by waiting for empty leader slot and delinquency
set -eu
# Adjust to where it is on your system
__ledger_dir=/home/sol/ledger
# Good default; as desired override when running the script
__delinquent=${1:-5}

cd /home/sol
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/agave-validator --ledger ${__ledger_dir} exit --max-delinquent-stake ${__delinquent} -m
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/agave-validator --ledger ${__ledger_dir} monitor
