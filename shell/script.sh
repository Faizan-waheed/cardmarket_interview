#!/usr/bin/env bash

STDOUT="/dev/stdout"
LOG_FILE="$STDOUT"
LOG_MESSAGE="is the date, should log to $STDOUT"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "$LOG_MESSAGE"
