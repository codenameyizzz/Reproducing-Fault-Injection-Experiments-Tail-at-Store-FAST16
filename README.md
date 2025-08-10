# Tail at Store (FAST '16) — Fault Injection Reproduction

**Firmware Tail Injection · RAID Tail Amplification · GC Slowness (and more)**

This README is a fully-detailed, **runnable** guide to reproduce our fault-injection experiments using a trace replayer derived from UChicago UCARE’s `trace-ACER`. It includes step-by-step setup from scratch, running single experiments, parameter sweeps, plotting, and troubleshooting.

---

## 0) At a Glance (Checklist)

- [ ] Ubuntu 20.04+ with `sudo` access on **bare metal** (recommended) or a VM
- [ ] NVMe device path (e.g., `/dev/nvme0n1`) you are allowed to read/write
- [ ] I/O traces in `~/traces/`
- [ ] Dependencies installed (`gcc`, `make`, `libaio-dev`, `python3-pip`, etc.)
- [ ] Repo cloned and our modified files in place
- [ ] Scripts made executable

---

## 1) Machine Requirements

- **OS**: Ubuntu 20.04 LTS (tested); 22.04 also works
- **CPU**: ≥ 4 cores (more is better for `nr_workers`)
- **RAM**: ≥ 8 GB
- **Disk**: NVMe SSD recommended (≥ 20 GB free)
- **Privileges**: `sudo` to access `/dev/nvme*`
- **Networking**: Required only for cloning and (optional) downloading traces

> ⚠️ **Data safety**: Running the replayer with `WRITE` requests can overwrite data on the target device. Use a dedicated device or a test partition you can safely destroy.

---

## 2) Dependencies Installation

```bash
sudo apt update
sudo apt install -y build-essential libaio-dev fio git python3 python3-pip
pip3 install --upgrade pip
pip3 install numpy pandas matplotlib
```

If you plan to plot on a headless server, set a non-interactive backend or save figures to files.

---

## 3) Get the Code

Clone the reference repo (for context) and place our modified sources alongside it.

```bash
# Clone upstream reference (optional but recommended for baseline comparison)
cd ~
git clone https://github.com/ucare-uchicago/trace-ACER.git
cd trace-ACER/trace_replayer

# Put our modified files here (copy from your working folder):
#  io_replayer.c            (multi-fault version with compile-time flags)
#  io_replayer_ftcx.c       (firmware tail injection CLI version)
#  io_replayer_raid.c       (RAID tail amplification CLI version)
#  conf_ftcx.sh
#  conf_gc_new.sh
#  conf_raid.sh
#  configure_fault.sh
#  sweep_experiment.sh
#  sweep_ftcx.sh
#
# If you're running this README from a different directory,
# just ensure the above files are present together.
```

Make scripts executable:

```bash
chmod +x conf_ftcx.sh conf_gc_new.sh conf_raid.sh configure_fault.sh \
           sweep_experiment.sh sweep_ftcx.sh
```

> Note: The source uses `#include "atomic.h"`. This header is in the upstream repo. Ensure it’s in the same directory as the `io_replayer*.c` files when compiling.

---

## 4) Traces

Place trace files in `~/traces/`. We used names like:

```
~/traces/trace_p100_sample10k_clean.trace
~/traces/trace_p15_sample10k_clean.trace
~/traces/trace_p100_sample100k.trace
```

### 4.1 If you already have traces

Copy them over:

```bash
mkdir -p ~/traces
# Example
cp /path/to/your/trace_p100_sample10k_clean.trace ~/traces/
```

### 4.2 If you do **not** have traces (quick synthetic generator)

Create a small, synthetic trace (READ-dominant) compatible with the replayer’s parser:

```bash
python3 - << 'PY'
import random,time,sys
random.seed(1)
N=10000  # number of I/Os
# format per line (space-separated):
# 1) ts(ms) 2) dev 3) blockNumber 4) sizeBlocks 5) flag(1=read,0=write)
# We keep simple: dev=0, sizeBlocks=8 (4KB*8=32KB), inter-arrival ~1 ms
cur_ts=0.0
with open('/home/$USER/traces/trace_synth_10k.trace'.replace('$USER','%s'%__import__('getpass').getuser()),'w') as f:
    for i in range(N):
        cur_ts += random.uniform(0.2, 1.5) # ms
        block = random.randint(0, 10**7)
        flag = 1 if random.random()<0.9 else 0  # 90% reads
        f.write(f"{cur_ts:.3f} 0 {block} 8 {flag}\n")
print("Synthetic trace written to ~/traces/trace_synth_10k.trace")
PY
```

---

## 5) Build Binaries

From the directory containing the C sources:

```bash
# Baseline multi-fault replayer (no fault enabled yet)
gcc io_replayer.c -o io_replayer -lpthread

# Firmware tail injection (FTCX) replayer
gcc io_replayer_ftcx.c -o io_replayer_ftcx -lpthread

# RAID tail amplification replayer
gcc io_replayer_raid.c -o io_replayer_raid -lpthread
```

---

## 6) Running Experiments (Single Runs)

### 6.1 Baseline (no fault)

```bash
sudo ./io_replayer /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace \
  ~/logs/baseline_p100_10k.log
```

- Output: `~/logs/baseline_p100_10k.log`
- Format: `ts_ms,lat_us,rw(1=r,0=w),size_B,offset_B,submit_ms,ret`

### 6.2 Firmware Tail Injection (FTCX)

Use the convenience script (interactive):

```bash
bash ./conf_ftcx.sh
```

It will ask for parameters:

- **Target disk ID** (logical, used by the code’s per-thread simulation)
- **Injection probability (%)**
- **Slow I/O count** (number of consecutive I/Os in *slow mode* once triggered)
- **Min/Max delay (µs)** in slow mode

**Direct CLI (no prompts):**

```bash
sudo ./io_replayer_ftcx -d 2 -p 10 -n 10 -m 100 -x 1000 \
  /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace \
  ~/logs/ftcx_d2_p10_n10_u100-1000.log
```

**What happens in code:**

- With probability `p%`, when the current thread hits **target_disk_id**, it enters *slow mode* for `n` I/Os; each of those gets a random delay in `[min,max]` µs.

### 6.3 RAID Tail Amplification

Interactive script:

```bash
bash ./conf_raid.sh
```

You’ll enter:

- **Delay (ms)**
- **Start offset** and **End offset** (only I/Os within this byte-range are affected)

**Direct CLI (no prompts):**

```bash
sudo ./io_replayer_raid /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace \
  ~/logs/raid_delay100ms_offset0-500M.log \
  -d 100 -r 1 -m 0 -x 524288000
```

- `-r 0` = WRITE only, `-r 1` = READ only, `-r 2` = BOTH
- Injection happens if the I/O offset is within `[start,end]`.

### 6.4 GC Slowness (burst-style GC pause windows)

Use the menu-driven configurator:

```bash
bash ./conf_gc_new.sh
# choose: gc_pause
# enter: GC_INTERVAL_MS, GC_JITTER_MS, GC_PAUSE_MIN_MS, GC_PAUSE_MAX_MS
```

Under the hood, it compiles:

```bash
gcc io_replayer.c -o io_replayer -lpthread \
  -DFAULT_GC_PAUSE \
  -DGC_INTERVAL_MS=<X> -DGC_JITTER_MS=<Y> \
  -DGC_PAUSE_MIN_MS=<A> -DGC_PAUSE_MAX_MS=<B>
```

Then runs:

```bash
sudo ./io_replayer /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace \
  ~/logs/gc_i<X>_j<Y>_min<A>_max<B>.log
```

**Behavior:** READs that land inside an **active GC window** get per-I/O delay. GC windows repeat every `GC_INTERVAL_MS ± JITTER` with per-window delay randomized between `[GC_PAUSE_MIN_MS, GC_PAUSE_MAX_MS]` (as configured in the script).

### 6.5 Other Fault Modes (compile-time toggles in `io_replayer.c`)

Launch the selector:

```bash
bash ./configure_fault.sh
```

Pick one of:

- `media_retries` (probabilistic retries with per-retry delay)
- `firmware_bug_random` (random extra delays/retries)
- `mlc_variability` (random slow-page factor for some percentage of I/Os)
- `ecc_read_retry` (bit-error → ECC retries with microsecond delays)
- `firmware_bandwidth_drop` (per-chunk throttling by factor)
- `voltage_read_retry` (READ-only extra retries/delays)
- `firmware_throttle` (random throttling + rare long “reboot hang”)
- `wear_pathology` (hot-channel congestion with extra microsecond delay)

The script prompts for parameters, compiles with `-DFAULT_...` flags, and runs a single replay. Logs are written to `~/logs/` with a descriptive filename tag.

---

## 7) Parameter Sweeps

### 7.1 Generic Sweeps (any compile-time param)

```
./sweep_experiment.sh FAULT PARAM START STEP END [KEY=VAL ...]
```

Example: sweep random delay for the *firmware_bug_random* fault while fixing other knobs.

```bash
./sweep_experiment.sh firmware_bug_random RANDOM_MAX_DELAY_MS 10 10 100 \
  INJECT_PCT=5 RANDOM_MAX_RETRIES=2
```

Outputs to `~/sweep_logs/firmware_bug_random_sweep_RANDOM_MAX_DELAY_MS/`

### 7.2 FTCX Sweeps (runtime params)

```
./sweep_ftcx.sh PARAM START STEP END [KEY=VAL ...]
```

Example: sweep `INJECT_PCT` while fixing other parameters:

```bash
./sweep_ftcx.sh INJECT_PCT 10 10 50 \
  TARGET_DISK_ID=2 FTCX_SLOW_IO_COUNT=5 DELAY_MIN_US=100 DELAY_MAX_US=1000
```

Outputs to `~/sweep_logs/firmware_tail_INJECT_PCT/`

---

## 8) Output & Layout

- Single-run logs → `~/logs/*.log`
- Sweeps → `~/sweep_logs/<fault>_*/*`
- Log format (CSV):

```
ts_ms, lat_us, rw(1=r,0=w), size_B, offset_B, submit_ms, ret_code
```

---

## 9) Plotting

### 9.1 Trend (Latency vs Time)

```python
import pandas as pd, matplotlib.pyplot as plt
df = pd.read_csv('~/logs/baseline_p100_10k.log', header=None,
                 names=['ts_ms','lat_us','rw','size','offset','submit_ms','ret'])
plt.plot(df['ts_ms'], df['lat_us'])
plt.xlabel('Time (ms)'); plt.ylabel('Latency (µs)')
plt.title('Latency Trend')
plt.tight_layout(); plt.show()
```

### 9.2 CDF Plot

```python
import numpy as np, pandas as pd, matplotlib.pyplot as plt
df = pd.read_csv('~/logs/baseline_p100_10k.log', header=None,
                 names=['ts_ms','lat_us','rw','size','offset','submit_ms','ret'])
lat = np.sort(df['lat_us'].values)
p = np.linspace(0,1,len(lat),endpoint=False)
plt.plot(lat,p)
plt.xlabel('Latency (µs)'); plt.ylabel('CDF')
plt.title('Latency CDF'); plt.grid(True, linestyle='--', alpha=0.3)
plt.tight_layout(); plt.show()
```

### 9.3 Multi-run comparison (baseline vs fault)

```python
import pandas as pd, matplotlib.pyplot as plt, glob
files=[
  '~/logs/baseline_p100_10k.log',
  '~/logs/ftcx_d2_p10_n10_u100-1000.log',
]
for f in files:
  df=pd.read_csv(f,header=None,names=['t','lat','rw','size','off','sub','ret'])
  plt.plot(df['t'], df['lat'], label=f.split('/')[-1])
plt.legend(); plt.xlabel('Time (ms)'); plt.ylabel('Latency (µs)')
plt.title('Trend Comparison'); plt.tight_layout(); plt.show()
```

---

## 10) Internals & Important Knobs

- **`nr_workers`**: thread count (default 64) — increase for more parallelism.
- **Respect time**: the replayer sleeps to honor trace timestamps; late/slack counters printed during progress.
- **Offset alignment**: requests are aligned to 4KB (`oft = oft/4096*4096`).
- **Fault toggles**: compile-time macros in `io_replayer.c` (e.g., `-DFAULT_GC_PAUSE`).
- **FTCX**: runtime flags (`-d -p -n -m -x`) and per-thread “slow mode”.

---

## 11) Troubleshooting

- **Permission denied on device**: use `sudo`, or fix device permissions.
- **`Cannot open trace`**: check path and filename; ensure read permission.
- **`atomic.h` missing**: ensure it’s in the same directory (from upstream repo).
- **No visible fault effect**:
  - Verify parameters are large enough (e.g., delay not too small).
  - Confirm the affected I/Os (e.g., offsets within range for RAID, reads for GC).
  - Try smaller trace first, then scale up.
- **Too slow / long runs**: use shorter traces or smaller parameter ranges.
- **Data safety**: run on a disposable device or set the replayer to READ-only traces if available.

---

## 12) End-to-End Minimal Example

```bash
# 1) Prepare folders and a synthetic trace
mkdir -p ~/traces ~/logs
python3 - << 'PY'
import random,getpass; random.seed(0)
p=f"/home/{getpass.getuser()}/traces/trace_synth_5k.trace"
with open(p,'w') as f:
  t=0.0
  for i in range(5000):
    t+=0.8; f.write(f"{t:.3f} 0 {random.randint(0,10**6)} 8 1\n")
print("Wrote",p)
PY

# 2) Build replayers
gcc io_replayer.c -o io_replayer -lpthread
gcc io_replayer_ftcx.c -o io_replayer_ftcx -lpthread
gcc io_replayer_raid.c -o io_replayer_raid -lpthread

# 3) Baseline
sudo ./io_replayer /dev/nvme0n1 ~/traces/trace_synth_5k.trace ~/logs/baseline_synth5k.log

# 4) FTCX: 20% chance to enter slow mode of 5 I/Os, delays 200–800 µs
sudo ./io_replayer_ftcx -d 2 -p 20 -n 5 -m 200 -x 800 \
  /dev/nvme0n1 ~/traces/trace_synth_5k.trace ~/logs/ftcx_synth5k.log

# 5) RAID: Inject 50 ms on READs within first 64 MB
sudo ./io_replayer_raid /dev/nvme0n1 ~/traces/trace_synth_5k.trace \
  ~/logs/raid_synth5k_50ms_0-64MB.log -d 50 -r 1 -m 0 -x $((64*1024*1024))
```

---

## 13) File Map (what you have in this folder)

```
io_replayer.c             # Multi-fault version (compile-time flags)
io_replayer_ftcx.c        # Firmware-tail injection (runtime flags)
io_replayer_raid.c        # RAID tail amplification (runtime flags)
conf_ftcx.sh              # Interactive runner for FTCX
conf_gc_new.sh            # Interactive GC runner (also other faults via menu)
conf_raid.sh              # Interactive RAID runner
configure_fault.sh        # Menu for all compile-time faults in io_replayer.c
sweep_experiment.sh       # Generic compile-time sweeps
sweep_ftcx.sh             # Runtime sweeps for FTCX
```

---

## 14) Notes on Reproducibility

- Fix random seeds where possible for consistent behavior (e.g., synthetic traces).
- Record the exact command, parameters, and git commit (if using the upstream repo).
- Store outputs under timestamped folders for each run or sweep.

---
