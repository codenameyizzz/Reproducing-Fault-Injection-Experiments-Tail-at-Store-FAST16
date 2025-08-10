#!/usr/bin/env bash
#
# sweep_experiment.sh: one-factor sweep for a single fault
#
# Usage:
#   ./sweep_experiment.sh FAULT PARAM START STEP END [KEY=VAL ...]
#
# Example:
#   ./sweep_experiment.sh firmware_bug_random RANDOM_MAX_DELAY_MS 10 10 100 \
    INJECT_PCT=5 RANDOM_MAX_RETRIES=2

set -e

if [ $# -lt 5 ]; then
  echo "Usage: $0 FAULT PARAM START STEP END [KEY=VAL ...]"
  exit 1
fi

FAULT=$1           # e.g. firmware_bug_random
PARAM=$2           # the #define to sweep, e.g. RANDOM_MAX_DELAY_MS
START=$3           # first value, e.g. 10
STEP=$4            # step increment, e.g. 10
END=$5             # last value, e.g. 100
shift 5

# Map the fault name to the actual compile‐time symbol in your C code
declare -A FAULTSYM=(
  [media_retries]=FAULT_MEDIA_RETRIES
  [firmware_bug_random]=FAULT_FW_RANDOM
  [gc_pause]=FAULT_GC_PAUSE
  [mlc_variability]=FAULT_MLC_VAR
  [ecc_read_retry]=FAULT_ECC_RETRY
  [firmware_bandwidth_drop]=FAULT_FW_BW_DROP
  [voltage_read_retry]=FAULT_VOLTAGE_RETRY
  [firmware_throttle]=FAULT_FW_THROTTLE
  [wear_pathology]=FAULT_WEAR_PATHOLOGY
)

SYM=${FAULTSYM[$FAULT]}
if [ -z "$SYM" ]; then
  echo "Unknown fault '$FAULT'"
  exit 1
fi

# collect any extra KEY=VAL pairs
EXTRA_DFLAGS=()
for kv in "$@"; do
  KEY=${kv%%=*}
  VAL=${kv#*=}
  EXTRA_DFLAGS+=( "-D${KEY}=${VAL}" )
done

SWEEP_DIR=~/sweep_logs/${FAULT}_sweep_${PARAM}
sudo mkdir -p "$SWEEP_DIR"

echo "▶ sweeping $FAULT via $PARAM from $START..$END by $STEP"
for v in $(seq "$START" "$STEP" "$END"); do
  echo
  echo "→ [$PARAM=$v]"

  # compile with the right FAULT_xxx and the PARAM set to $v
  gcc io_replayer.c -o io_replayer -lpthread \
      -D${SYM} -D${PARAM}=${v} "${EXTRA_DFLAGS[@]}"

  LOGFILE="${SWEEP_DIR}/trace_p100_sample100k_${FAULT}_${PARAM}${v}.log"
  echo "   Running → ${LOGFILE}"
  sudo ./io_replayer /dev/nvme0n1 ~/traces/trace_p100_sample100k.trace "${LOGFILE}"
done

echo
echo "✅ Sweep complete: logs in ${SWEEP_DIR}"

