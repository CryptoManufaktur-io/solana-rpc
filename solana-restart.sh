#!/usr/bin/env bash
# Safely restart Solana by waiting for empty leader slot and delinquency
set -e

cd /home/sol
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/solana-validator exit -m
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/solana-validator monitor
