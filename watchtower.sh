#!/bin/bash

# Get current directory and service name
WORK_DIR=$(dirname "$(readlink -f "${BASH_SOURCE}")") # Note this should remain this, it just directory to save log file from watchtower
SERVICE_NAME="agave-watchtower"
USERNAME=sol

# Create log file and change permissions to everyone readwrite-execute
sudo touch /tmp/solana-rpc-watchtower.log && sudo chmod 666 /tmp/solana-rpc-watchtower.log

# Install log rotate
sudo apt update && sudo apt install -y apache2-utils

# Check if the service is already running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "$SERVICE_NAME is already running."
else
    # Create the service unit file
    SERVICE_UNIT="[Unit]
Description=Agave Watchtower Service

[Service]
ExecStart=/bin/bash -c \"agave-watchtower --config /home/sol/.config/solana/cli/config.yml --interval 15 2>&1 | tee >(rotatelogs -t /tmp/solana-rpc-watchtower.log 30M)\"
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
