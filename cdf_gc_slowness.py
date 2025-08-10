import os
import numpy as np
import matplotlib.pyplot as plt

def load_latencies(path, cap=None):
    latencies = []
    with open(path, 'r') as f:
        for line in f:
            fields = line.strip().split(',')
            if len(fields) >= 2:
                try:
                    lat = float(fields[1])
                    if cap is None or lat <= cap:
                        latencies.append(lat)
                except ValueError:
                    continue
    return latencies

# === Ganti dengan direktori lokal kamu ===
log_dir = r"D:\[Backup] Repo\hasil_log"

# === Daftar file log hasil sweep GC_PAUSE_MULTIPLIER + baseline ===
multipliers = [50, 100, 150, 200, 250, 300, "baseline"]
log_files = [
    f"trace_p100_sample10k_clean.trace_gc_pause_GC_PAUSE_MULTIPLIER{m}.log" if m != "baseline"
    else "trace_baseline.log"
    for m in multipliers
]

plt.figure(figsize=(12, 6))

for m, file in zip(multipliers, log_files):
    full_path = os.path.join(log_dir, file)
    latencies = load_latencies(full_path)
    if not latencies:
        print(f"⚠️  Warning: no latencies in {file}")
        continue
    latencies = np.sort(latencies)
    cdf = np.arange(len(latencies)) / len(latencies)
    
    label = f"Multiplier={m}" if m != "baseline" else "Baseline"
    plt.plot(latencies, cdf * 100, label=label)

plt.xscale("log")
plt.xlabel("Latency (µs, log scale)")
plt.ylabel("CDF (%)")
plt.title("CDF Plot: GC Pause Latency vs Baseline (Sweep GC_PAUSE_MULTIPLIER)")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("cdf_gc_pause_with_baseline.png", dpi=300)
plt.show()
