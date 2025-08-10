#!/bin/bash
set -e

DEVICE="/dev/nvme0n1"
TRACE_PATH="/home/cc/traces/trace_p100_sample10k_clean.trace"
OUTDIR="/home/cc/sweep_logs/ftcx_grid"
mkdir -p "$OUTDIR"

DISK_ID=2
SLOW_IO_COUNT=10
DELAY_MIN_US=100

for P in 5 10 15 20 25 30; do
    for DMAX in 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000; do
        echo "Sweeping P=${P}%, Delay Max=${DMAX} µs"

        LOGFILE="${OUTDIR}/trace_ftcx_P${P}_D${DMAX}.log"

        sudo TARGET_DISK_ID=$DISK_ID \
            INJECT_PCT=$P \
            FTCX_SLOW_IO_COUNT=$SLOW_IO_COUNT \
            DELAY_MIN_US=$DELAY_MIN_US \
            DELAY_MAX_US=$DMAX \
            ./io_replayer_ftcx "$DEVICE" "$TRACE_PATH" "$LOGFILE"
    done
done

echo "Grid sweep complete. Logs in $OUTDIR"
