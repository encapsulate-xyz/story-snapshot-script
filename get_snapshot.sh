#!/bin/bash

# Enable error handling
set -e

# Variables for default service names
DEFAULT_EXEC_SERVICE="story-geth"
DEFAULT_CONSENSUS_SERVICE="story"

# Function to log messages with timestamps
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Main menu using TUI with whiptail
EXEC_SERVICE=$(whiptail --inputbox "Enter Execution Service name" 10 60 "$DEFAULT_EXEC_SERVICE" 3>&1 1>&2 2>&3)
CONSENSUS_SERVICE=$(whiptail --inputbox "Enter Consensus Service name" 10 60 "$DEFAULT_CONSENSUS_SERVICE" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  log "User cancelled input. Exiting."
  exit 1
fi

# TUI for snapshot type selection
SNAPSHOT_TYPE=$(whiptail --title "Snapshot Type" --radiolist \
"Choose the snapshot type:" 15 60 2 \
"Pruned" "Lightweight snapshot" ON \
"Archive" "Full blockchain history" OFF 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  log "User cancelled snapshot selection. Exiting."
  exit 1
fi

# Set URLs based on snapshot type
if [ "$SNAPSHOT_TYPE" == "Pruned" ]; then
  GETH_URL="https://snapshot.encapsulate.xyz/story/pruned/story_geth_snapshot_pruned.lz4"
  CONSENSUS_URL="https://snapshot.encapsulate.xyz/story/pruned/story_snapshot_pruned.lz4"
elif [ "$SNAPSHOT_TYPE" == "Archive" ]; then
  GETH_URL="https://snapshot.encapsulate.xyz/story/archive/story_geth_snapshot_archive.lz4"
  CONSENSUS_URL="https://snapshot.encapsulate.xyz/story/archive/story_snapshot_archive.lz4"
else
  log "Invalid snapshot type. Exiting."
  exit 1
fi

log "Selected $SNAPSHOT_TYPE snapshot."

# Update system and install dependencies
log "Updating system and installing prerequisites..."
sudo apt update
sudo apt install snapd -y
sudo snap install lz4

# Stop services
log "Stopping services: $EXEC_SERVICE and $CONSENSUS_SERVICE..."
sudo systemctl stop "$EXEC_SERVICE"
sudo systemctl stop "$CONSENSUS_SERVICE"

# Remove existing data
log "Removing old execution data..."
sudo rm -rf "$HOME/.story/geth/iliad/geth/chaindata"

log "Removing old consensus data..."
sudo rm -rf "$HOME/.story/story/data"

# Download and extract snapshots
log "Downloading and extracting execution snapshot..."
cd "$HOME/.story/geth/iliad/geth"
curl -o - -L "$GETH_URL" | lz4 -c -d - | tar -x
log "Execution snapshot extracted successfully."

log "Downloading and extracting consensus snapshot..."
cd "$HOME/.story/story"
curl -o - -L "$CONSENSUS_URL" | lz4 -c -d - | tar -x
log "Consensus snapshot extracted successfully."

# Restart services
log "Restarting services: $EXEC_SERVICE and $CONSENSUS_SERVICE..."
sudo systemctl start "$EXEC_SERVICE"
sudo systemctl start "$CONSENSUS_SERVICE"

# Log completion
log "Snapshot restoration and service restart completed successfully."