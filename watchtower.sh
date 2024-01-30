#!/bin/bash

# Get current directory and service name
WORK_DIR=$(dirname "$(readlink -f "${BASH_SOURCE}")")
SERVICE_NAME="solana-watchtower"
USERNAME=$(whoami)

# Install log rotate
sudo apt update && sudo apt install -y apache2-utils

# Check if the service is already running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "$SERVICE_NAME is already running."
else
    # Create the service unit file
    SERVICE_UNIT="[Unit]
Description=Solana Watchtower Service

[Service]
ExecStart=/bin/bash -c \"solana-watchtower --interval 15 2>&1 | tee >(rotatelogs -n 5 $WORK_DIR/watchtower.log 30M)\"
Restart=always
User=$USERNAME
WorkingDirectory=$WORK_DIR

[Install]
WantedBy=multi-user.target"

    # Save the service unit file to the systemd directory
    echo -e "$SERVICE_UNIT" | sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null

    # Reload systemd and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"

    echo "$SERVICE_NAME service has been set up and started."
fi
