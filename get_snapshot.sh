#!/bin/bash

# Enable error handling
set -e

# Snapshot URLs
ARCHIVAL_GETH_SNAPSHOT="https://snapshot.encapsulate.xyz/story/archive/story_geth_snapshot_archive.lz4"
ARCHIVAL_STORY_SNAPSHOT="https://snapshot.encapsulate.xyz/story/archive/story_snapshot_archive.lz4"
PRUNED_GETH_SNAPSHOT="https://snapshot.encapsulate.xyz/story/pruned/story_geth_snapshot_pruned.lz4"
PRUNED_STORY_SNAPSHOT="https://snapshot.encapsulate.xyz/story/pruned/story_snapshot_pruned.lz4"

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

log "Selected $SNAPSHOT_TYPE snapshot."

# Update system and install dependencies
log "Updating system and installing prerequisites..."
sudo apt update
sudo apt install lz4 -y

# Stop services
log "Stopping services: $EXEC_SERVICE and $CONSENSUS_SERVICE..."
sudo systemctl stop "$EXEC_SERVICE"
sudo systemctl stop "$CONSENSUS_SERVICE"

# Backup priv_validator_state.json
log "Backing up priv_validator_state.json..."
cp ~/.story/story/data/priv_validator_state.json ~/.story/story/priv_validator_state.json.backup

# Download snapshots based on snapshot type
if [ "$SNAPSHOT_TYPE" == "Pruned" ]; then
  wget $PRUNED_GETH_SNAPSHOT -O geth_snapshot.lz4
  wget $PRUNED_STORY_SNAPSHOT -O story_snapshot.lz4
elif [ "$SNAPSHOT_TYPE" == "Archive" ]; then
  wget $ARCHIVAL_GETH_SNAPSHOT -O geth_snapshot.lz4
  wget $ARCHIVAL_STORY_SNAPSHOT -O story_snapshot.lz4
else
  log "Invalid snapshot type. Exiting."
  exit 1
fi

# Remove existing data
log "Removing old execution data..."
sudo rm -rf "$HOME/.story/geth/iliad/geth/chaindata"

log "Removing old consensus data..."
sudo rm -rf "$HOME/.story/story/data"

# Extract snapshots
log "Extracting execution snapshot..."
lz4 -d geth_snapshot.lz4 | tar -C ~/.story/geth/iliad/geth -xv

log "Extracting consensus snapshot..."
lz4 -d story_snapshot.lz4 | tar -C ~/.story/story -xv

log "Removing snapshot files..."
rm -rf geth_snapshot.lz4 story_snapshot.lz4

# Restore priv_validator_state.json
log "Restoring priv_validator_state.json..."
mv ~/.story/story/priv_validator_state.json.backup ~/.story/story/data/priv_validator_state.json

# Restart services
log "Restarting services: $EXEC_SERVICE and $CONSENSUS_SERVICE..."
sudo systemctl start "$EXEC_SERVICE"
sudo systemctl start "$CONSENSUS_SERVICE"

# Log completion
log "Snapshot restoration and service restart completed successfully."
