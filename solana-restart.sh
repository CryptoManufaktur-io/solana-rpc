#!/usr/bin/env bash
# Safely restart Solana by waiting for empty leader slot and delinquency
cd /home/sol
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/solana-validator wait-for-restart-window
sudo systemctl restart validator
sudo -u sol /home/sol/.local/share/solana/install/active_release/bin/solana-validator monitor
