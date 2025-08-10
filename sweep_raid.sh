#!/usr/bin/env bash
set -e

if [ $# -lt 5 ]; then
  echo "Usage: $0 START STEP END OFFSET_START OFFSET_END"
  echo "Example: ./sweep_raid.sh 5 5 50 8500000000 8700000000"
  exit 1
fi

START=$1
STEP=$2
END=$3
OFFSET_START=$4
OFFSET_END=$5

TRACE=~/traces/trace_p100_google_sample10k.trace
LOGDIR=~/sweep_logs/raid_delay_sweep
mkdir -p "$LOGDIR"

echo " Building..."
gcc io_replayer_raid.c -o io_replayer_raid -lpthread

for DELAY in $(seq $START $STEP $END); do
  echo " Running RAID delay injection = $DELAY ms"

  LOGFILE=$LOGDIR/trace_raid_delay${DELAY}_start${OFFSET_START}_end${OFFSET_END}.log

  sudo ./io_replayer_raid \
    /dev/nvme0n1 \
    "$TRACE" \
    "$LOGFILE" \
    -d "$DELAY" \
    -m "$OFFSET_START" \
    -x "$OFFSET_END" \
    -r 1

done

echo " Sweep complete. Logs in $LOGDIR"
