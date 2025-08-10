#!/bin/bash
# sweep_ftcx.sh: Sweep INJECT_PCT for FTCX

set -e

if [ $# -lt 5 ]; then
  echo "Usage: $0 PARAM START STEP END [KEY=VAL ...]"
  exit 1
fi

PARAM=$1
START=$2
STEP=$3
END=$4
shift 4

# Default values
DEV="/dev/nvme0n1"
TRACE="/home/cc/traces/trace_p15_sample10k_clean.trace"
SWEEP_DIR=/home/cc/sweep_logs/firmware_tail_${PARAM}
mkdir -p "$SWEEP_DIR"

# Parse extra args
for kv in "$@"; do
  eval "$kv"
done

echo " Sweeping $PARAM from $START to $END (step=$STEP)"
gcc io_replayer_ftcx.c -o io_replayer_ftcx -lpthread

for val in $(seq $START $STEP $END); do
  echo "→ [$PARAM=$val]"

  # Overwrite the parameter being swept
  eval "$PARAM=$val"

  LOG="${SWEEP_DIR}/trace_ftcx_${PARAM}${val}.log"
  sudo ./io_replayer_ftcx -d ${TARGET_DISK_ID:-2} -p ${INJECT_PCT:-$val} \
       -n ${FTCX_SLOW_IO_COUNT:-10} -m ${DELAY_MIN_US:-100} -x ${DELAY_MAX_US:-1000} \
       $DEV $TRACE $LOG
done

echo "Sweep complete: logs in $SWEEP_DIR"