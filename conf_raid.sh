#!/usr/bin/env bash
set -e

echo "RAID Tail Amplification - Manual Config"

read -p "Injection delay (ms): " DELAY
read -p "Injection start offset (e.g., 0): " START
read -p "Injection end offset (e.g., 500000000): " END

DEVICE=/dev/nvme0n1
TRACE=~/traces/trace_p100_sample10k_clean.trace
LOGDIR=~/logs
mkdir -p "$LOGDIR"
LOGFILE=$LOGDIR/trace_raid_delay${DELAY}_start${START}_end${END}.log

echo "Building..."
gcc io_replayer_raid.c -o io_replayer_raid -lpthread

echo "Running RAID injection..."
sudo ./io_replayer_raid "$DEVICE" "$TRACE" "$LOGFILE" \
  -d "$DELAY" \
  -r 1 \
  -m "$START" \
  -x "$END"

echo "Done. Output: $LOGFILE"
