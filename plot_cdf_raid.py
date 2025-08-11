import matplotlib.pyplot as plt
import numpy as np
import os

def load_latencies(path, latency_cap=None):
    latencies = []
    with open(path, 'r') as f:
        for line in f:
            fields = line.strip().split(',')
            if len(fields) >= 2:
                try:
                    l = float(fields[1])
                    if latency_cap is None or l <= latency_cap:
                        latencies.append(l)
                except ValueError:
                    continue
    return latencies

log_dir = r"D:\Repo\hasil_log"  # change this to the path of the log files

log_files = [
    "baseline_10k.log",
    "trace_raid_D10.log",
    "trace_raid_D20.log",
    "trace_raid_D30.log",
    "trace_raid_D40.log",
    "trace_raid_D50.log"
]

labels = {
    "baseline_10k.log": "Baseline",
    "trace_raid_D10.log": "Delay = 10ms",
    "trace_raid_D20.log": "Delay = 20ms",
    "trace_raid_D30.log": "Delay = 30ms",
    "trace_raid_D40.log": "Delay = 40ms",
    "trace_raid_D50.log": "Delay = 50ms",
}

plt.figure(figsize=(12, 6))
latency_cap = None  # set this to the latency cap you want to use
for file in log_files:
    path = os.path.join(log_dir, file)
    latencies = load_latencies(path, latency_cap)
    if not latencies:
        print(f"⚠️ Warning: no latencies found in {file}")
        continue
    latencies = np.sort(np.array(latencies))
    cdf = np.arange(len(latencies)) / len(latencies)
    plt.plot(latencies, cdf * 100, label=labels.get(file, file), linewidth=1.3)

plt.xscale("log")
plt.xlabel("Latency (µs, log scale)")
plt.ylabel("CDF (%)")
plt.title("Latency CDF: RAID Tail Amplification vs Baseline")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("cdf_raid_tail_sweep.png", dpi=300)
plt.show()
