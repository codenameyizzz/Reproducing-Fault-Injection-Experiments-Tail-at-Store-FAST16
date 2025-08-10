#!/bin/bash
# conf_ftcx.sh: run single firmware_tail injection (FTCX)

set -e

echo "Firmware Tail Injection (FTCX)"
read -p "Target disk ID (e.g., 2): " TARGET_DISK_ID
read -p "Injection probability (%) [0–100]: " INJECT_PCT
read -p "Slow I/O count: " FTCX_SLOW_IO_COUNT
read -p "Min delay per I/O (us): " DELAY_MIN_US
read -p "Max delay per I/O (us): " DELAY_MAX_US

# Path setup
DEV="/dev/nvme0n1"
TRACE="/home/cc/traces/trace_p100_sample10k_clean.trace" 
LOG="/home/cc/logs/trace_p100_sample10k_ftcx_d${TARGET_DISK_ID}_p${INJECT_PCT}_n${FTCX_SLOW_IO_COUNT}_u${DELAY_MIN_US}-${DELAY_MAX_US}.log"

echo "Compiling io_replayer_ftcx..."
gcc io_replayer_ftcx.c -o io_replayer_ftcx -lpthread

echo "Running..."
sudo ./io_replayer_ftcx -d $TARGET_DISK_ID -p $INJECT_PCT -n $FTCX_SLOW_IO_COUNT \
                        -m $DELAY_MIN_US -x $DELAY_MAX_US \
                        $DEV $TRACE $LOG

echo "Done. Log  $LOG"