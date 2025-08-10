
#!/usr/bin/env bash
#
# configure_fault.sh: choose a fault, set params, build & run io_replayer
#

set -e

# 1) Paths & defaults
REPLAYER_SOURCE=io_replayer.c
BINARY=io_replayer
DEVICE=/dev/nvme0n1
TRACE=~/traces/trace_p100_sample100k.trace
LOGDIR=~/logs

# 2) Pick one of our faults
echo "Select fault to inject:"
select FAULT in \
  media_retries \
  firmware_bug_random \
  gc_pause \
  mlc_variability \
  ecc_read_retry \
  firmware_bandwidth_drop \
  voltage_read_retry \
  firmware_throttle  \
  wear_pathology; do
  [ -n "$FAULT" ] && break
done

# 3) Fault-specific prompts and compile-time defines
EXTRA_DEFS=""
LOGTAG="${FAULT}"
case $FAULT in
  media_retries)
    read -p "Enter injection probability (%) [0–100]: " INJECT_PCT
    read -p "Enter max retries per error event: " MAX_MEDIA_RETRIES
    read -p "Enter per-retry delay (ms): " MEDIA_RETRY_DELAY_MS
    EXTRA_DEFS="
      -DFAULT_MEDIA_RETRIES \
      -DINJECT_PCT=${INJECT_PCT} \
      -DMAX_MEDIA_RETRIES=${MAX_MEDIA_RETRIES} \
      -DMEDIA_RETRY_DELAY_MS=${MEDIA_RETRY_DELAY_MS}"
    LOGTAG="${FAULT}_p${INJECT_PCT}_r${MAX_MEDIA_RETRIES}_d${MEDIA_RETRY_DELAY_MS}"
    ;;
  firmware_bug_random)
    read -p "Enter injection probability (%) [0–100]: " INJECT_PCT
    read -p "Enter max random-delay (ms): " RANDOM_MAX_DELAY_MS
    read -p "Enter max random-retries per injection: " RANDOM_MAX_RETRIES
    EXTRA_DEFS="
      -DFAULT_FW_RANDOM \
      -DINJECT_PCT=${INJECT_PCT} \
      -DRANDOM_MAX_DELAY_MS=${RANDOM_MAX_DELAY_MS} \
      -DRANDOM_MAX_RETRIES=${RANDOM_MAX_RETRIES}"
    LOGTAG="${FAULT}_p${INJECT_PCT}_d${RANDOM_MAX_DELAY_MS}_r${RANDOM_MAX_RETRIES}"
    ;;
  gc_pause)
    read -p "Enter average GC interval (ms): "     GC_INTERVAL_MS
    read -p "Enter GC interval jitter (±ms): "      GC_JITTER_MS
    read -p "Enter min GC pause (ms): "            GC_PAUSE_MIN_MS
    read -p "Enter max GC pause (ms): "            GC_PAUSE_MAX_MS
    EXTRA_DEFS="
      -DFAULT_GC_PAUSE \
      -DGC_INTERVAL_MS=${GC_INTERVAL_MS} \
      -DGC_JITTER_MS=${GC_JITTER_MS} \
      -DGC_PAUSE_MIN_MS=${GC_PAUSE_MIN_MS} \
      -DGC_PAUSE_MAX_MS=${GC_PAUSE_MAX_MS}"
    LOGTAG="${FAULT}_i${GC_INTERVAL_MS}_j${GC_JITTER_MS}_min${GC_PAUSE_MIN_MS}_max${GC_PAUSE_MAX_MS}"
    ;;
  mlc_variability)
    read -p "Enter slow-page rate (%) [0–100]: " SLOW_PAGE_RATE
    read -p "Enter max slow-page factor (e.g. 8 for up to 8× slower): " MLC_SLOW_FACTOR
    EXTRA_DEFS="
      -DFAULT_MLC_VAR \
      -DSLOW_PAGE_RATE=${SLOW_PAGE_RATE} \
      -DMLC_SLOW_FACTOR=${MLC_SLOW_FACTOR}"
    LOGTAG="${FAULT}_r${SLOW_PAGE_RATE}_f${MLC_SLOW_FACTOR}"
    ;;
  ecc_read_retry)
    read -p "Enter bit-error rate (%) [0–100]: " ECC_ERROR_PCT
    read -p "Enter max ECC retries per error event: " MAX_ECC_RETRIES
    read -p "Enter min per-retry delay (µs): " MIN_ECC_DELAY_US
    read -p "Enter max per-retry delay (µs): " MAX_ECC_DELAY_US
    EXTRA_DEFS="
      -DFAULT_ECC_RETRY \
      -DECC_ERROR_PCT=${ECC_ERROR_PCT} \
      -DMAX_ECC_RETRIES=${MAX_ECC_RETRIES} \
      -DMIN_ECC_DELAY_US=${MIN_ECC_DELAY_US} \
      -DMAX_ECC_DELAY_US=${MAX_ECC_DELAY_US}"
    LOGTAG="${FAULT}_e${ECC_ERROR_PCT}_r${MAX_ECC_RETRIES}_d${MIN_ECC_DELAY_US}-${MAX_ECC_DELAY_US}"
    ;;
  firmware_bandwidth_drop)
    read -p "Enter injection probability (%) [0–100]: " INJECT_PCT
    read -p "Enter max bandwidth-drop factor (e.g. 3 for up to 3× slower): " FW_BW_FACTOR
    # we throttle in 250µs increments to reflect real-world report
    EXTRA_DEFS="
      -DFAULT_FW_BW_DROP \
      -DINJECT_PCT=${INJECT_PCT} \
      -DTHROTTLE_UNIT_US=250 \
      -DFW_BW_FACTOR=${FW_BW_FACTOR}"
    LOGTAG="${FAULT}_p${INJECT_PCT}_bw${FW_BW_FACTOR}"
    ;;
  voltage_read_retry)
    read -p "Enter borderline-cell rate (%) [0–100]: " INJECT_PCT
    read -p "Enter max read-retry count: " RETRY_COUNT
    read -p "Enter min per-retry delay (µs): " MIN_DELAY_US
    read -p "Enter max per-retry delay (µs): " MAX_DELAY_US
    EXTRA_DEFS="
      -DFAULT_VOLTAGE_RETRY \
      -DINJECT_PCT=${INJECT_PCT} \
      -DRETRY_COUNT=${RETRY_COUNT} \
      -DMIN_DELAY_US=${MIN_DELAY_US} \
      -DMAX_DELAY_US=${MAX_DELAY_US}"
    LOGTAG="voltageread_p${INJECT_PCT}_c${RETRY_COUNT}_d${MIN_DELAY_US}-${MAX_DELAY_US}"
    ;;
  firmware_throttle)
    read -p "Throttle injection rate (%) [0–100]: " INJECT_PCT
    read -p "Max throttle multiplier (N): " MAX_THROTTLE
    read -p "Reboot chance per I/O (%) [0–100]: " REBOOT_PCT
    read -p "Max reboot hang (s): " MAX_HANG_S
    EXTRA_DEFS="
      -DFAULT_FW_THROTTLE \
      -DINJECT_PCT=${INJECT_PCT} \
      -DTHROTTLE_UNIT_US=250 \
      -DMAX_THROTTLE_MUL=${MAX_THROTTLE} \
      -DREBOOT_CHANCE_PCT=${REBOOT_PCT} \
      -DMAX_REBOOT_HANG_S=${MAX_HANG_S}"
    LOGTAG="${FAULT}_i${INJECT_PCT}_m${MAX_THROTTLE}_p${REBOOT_PCT}_h${MAX_HANG_S}"
    ;;
  wear_pathology)
    read -p "Hot-channel injection rate (%) [0–100]: " WEAR_PCT
    read -p "Min per-I/O delay on hot channel (µs): " WEAR_MIN_US
    read -p "Max per-I/O delay on hot channel (µs): " WEAR_MAX_US
    read -p "Total number of SSD channels (NCHANNELS) [default 16]: " TOTAL_CHANNELS
    TOTAL_CHANNELS=${TOTAL_CHANNELS:-16}
    read -p "Number of hot channels to congest [1–$TOTAL_CHANNELS]: " MAX_HOT_CHANNELS
    EXTRA_DEFS="
      -DFAULT_WEAR_PATHOLOGY \
      -DWEAR_PCT=${WEAR_PCT} \
      -DWEAR_MIN_US=${WEAR_MIN_US} \
      -DWEAR_MAX_US=${WEAR_MAX_US} \
      -DNCHANNELS=${TOTAL_CHANNELS} \
      -DMAX_HOT_CHANNELS=${MAX_HOT_CHANNELS}"
    LOGTAG="${FAULT}_p${WEAR_PCT}_u${WEAR_MIN_US}-${WEAR_MAX_US}_H${MAX_HOT_CHANNELS}"
    ;;
esac

# 4) Output logfile
LOGFILE=${LOGDIR}/trace_p100_sample100k_${LOGTAG}.log

# 5) Compile
echo "Building ${BINARY} with fault=${FAULT}..."
gcc ${REPLAYER_SOURCE} -o ${BINARY} -lpthread ${EXTRA_DEFS}

# 6) Run
echo "Running ./${BINARY} on ${TRACE} → ${LOGFILE} ..."
sudo ./${BINARY} ${DEVICE} ${TRACE} ${LOGFILE}
echo "Finished.  Stats in ${LOGFILE}.stats"
