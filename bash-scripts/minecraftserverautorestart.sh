#!/bin/bash

# Configuration
# Path to the directory containing the FTB server
FTB_SERVER_DIR="/path/to/server/folder"
# The command to start the FTB server
START_SERVER_CMD="./start.sh"
# Server log file where we can check for server status
SERVER_LOG_FILE="server.log"

# Change to the server directory
cd "$FTB_SERVER_DIR"

# Function to check if the server is running
is_server_running() {
    # Check if the server process is running
    if pgrep -f "$START_SERVER_CMD" > /dev/null ; then
        return 0
    else
        return 1
    fi
}

# Function to start the server
start_server() {
    echo "Starting the FTB server..."
    # Start the server in a screen session named 'FTBServer'
    screen -dmS FTBServer bash -c "$START_SERVER_CMD | tee -a $SERVER_LOG_FILE"
}

# Infinite loop to check server status and restart if not running
while true; do
    if is_server_running; then
        echo "FTB server is currently running."
    else
        echo "FTB server is not running. Starting server..."
        start_server
    fi
    # Wait for 1 minute before checking again
    sleep 60
done