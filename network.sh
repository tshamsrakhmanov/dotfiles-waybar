#!/bin/bash

# Find your active network interface
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

# If no interface is found, exit
if [ -z "$INTERFACE" ]; then
    echo '{"text": "↓   0K  ↑   0K"}'
    exit 0
fi

# File to store previous stats
STATS_FILE="/tmp/waybar_net_stats"

# Get current RX/TX bytes from /proc/net/dev
read -r RX_BYTES_NOW TX_BYTES_NOW <<< $(awk -v iface="$INTERFACE" '$1 ~ iface":" {print $2, $10}' /proc/net/dev)
TIME_NOW=$(date +%s%N)

# If no stats file, create one and output initial
if [ ! -f "$STATS_FILE" ]; then
    echo "PREV_TIME=$TIME_NOW" > "$STATS_FILE"
    echo "PREV_RX_BYTES=$RX_BYTES_NOW" >> "$STATS_FILE"
    echo "PREV_TX_BYTES=$TX_BYTES_NOW" >> "$STATS_FILE"
    echo '{"text": "↓   0K  ↑   0K"}'
    exit 0
fi

# Read previous stats
source "$STATS_FILE"

# Calculate speed in bytes per second
TIME_DIFF=$(( (TIME_NOW - PREV_TIME) / 1000000 )) # in milliseconds

# Ensure we have valid numbers and time difference is positive
if [ "$TIME_DIFF" -gt 0 ] && [ -n "$PREV_RX_BYTES" ] && [ -n "$PREV_TX_BYTES" ]; then
    RX_SPEED=$(( (RX_BYTES_NOW - PREV_RX_BYTES) / (TIME_DIFF / 1000) ))
    TX_SPEED=$(( (TX_BYTES_NOW - PREV_TX_BYTES) / (TIME_DIFF / 1000) ))
    
    # Prevent negative values (in case of interface reset)
    [ "$RX_SPEED" -lt 0 ] && RX_SPEED=0
    [ "$TX_SPEED" -lt 0 ] && TX_SPEED=0
else
    RX_SPEED=0
    TX_SPEED=0
fi

# Format speed with fixed width (always 5 chars: 4 digits/spaces + 1 unit)
format_speed() {
    local bytes=$1
    
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "   0K"
        return
    fi
    
    if [ "$bytes" -gt 1048576 ]; then
        printf "%4dM" $((bytes / 1048576))
    elif [ "$bytes" -gt 1024 ]; then
        printf "%4dK" $((bytes / 1024))
    else
        printf "%4dB" "$bytes"
    fi
}

# Format both speeds
RX_HR=$(format_speed "$RX_SPEED")
TX_HR=$(format_speed "$TX_SPEED")

# Update stats file for next run
cat > "$STATS_FILE" <<EOF
PREV_TIME=$TIME_NOW
PREV_RX_BYTES=$RX_BYTES_NOW
PREV_TX_BYTES=$TX_BYTES_NOW
EOF

# Output JSON for Waybar
echo "{\"text\": \"↓$RX_HR  ↑$TX_HR\"}"
