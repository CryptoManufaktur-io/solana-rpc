#!/usr/bin/env bash
# Only when required, manually grab snapshots from Solana labs
set -e

sudo -u sol mkdir -p /home/sol/ledger
cd /home/sol/ledger
sudo -u sol wget --trust-server-names http://145.40.67.83/snapshot.tar.bz2
sudo -u sol wget --trust-server-names http://145.40.67.83/incremental-snapshot.tar.bz2
