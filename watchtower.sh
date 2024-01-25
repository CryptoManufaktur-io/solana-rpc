#!/bin/bash

# Get current directory
WORK_DIR=$(dirname "$(readlink -f "${BASH_SOURCE}")")

# Install log rotate
sudo apt update && sudo apt install -y apache2-utils

# Kill previous tasks if any
killall solana-watchtower

# Start watchtower
solana-watchtower --interval 15 &> >(rotatelogs -n 5 $WORK_DIR/watchtower.log 30M) &
