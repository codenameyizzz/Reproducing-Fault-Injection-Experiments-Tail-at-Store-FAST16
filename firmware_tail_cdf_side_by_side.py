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

# log directory
log_dir = os.path.dirname(__file__)  # automatically in the script folder

# configure files for injection probability
prob_files = [
    "baseline_10k.log",
    "trace_ftcx_INJECT_PCT5.log",
    "trace_ftcx_INJECT_PCT10.log",
    "trace_ftcx_INJECT_PCT15.log",
    "trace_ftcx_INJECT_PCT20.log",
    "trace_ftcx_INJECT_PCT25.log",
    "trace_ftcx_INJECT_PCT30.log"
]

prob_labels = {
    "baseline_10k.log": "Baseline",
    "trace_ftcx_INJECT_PCT5.log": "P=5%",
    "trace_ftcx_INJECT_PCT10.log": "P=10%",
    "trace_ftcx_INJECT_PCT15.log": "P=15%",
    "trace_ftcx_INJECT_PCT20.log": "P=20%",
    "trace_ftcx_INJECT_PCT25.log": "P=25%",
    "trace_ftcx_INJECT_PCT30.log": "P=30%",
}

# configure files for max delay
delay_files = [
    "baseline_10k.log",
    "trace_ftcx_DELAY_MAX_US1000.log",
    "trace_ftcx_DELAY_MAX_US3000.log",
    "trace_ftcx_DELAY_MAX_US5000.log",
    "trace_ftcx_DELAY_MAX_US7000.log",
    "trace_ftcx_DELAY_MAX_US10000.log"
]

delay_labels = {
    "baseline_10k.log": "Baseline",
    "trace_ftcx_DELAY_MAX_US1000.log": "Max Delay = 1s",
    "trace_ftcx_DELAY_MAX_US3000.log": "Max Delay = 3s",
    "trace_ftcx_DELAY_MAX_US5000.log": "Max Delay = 5s",
    "trace_ftcx_DELAY_MAX_US7000.log": "Max Delay = 7s",
    "trace_ftcx_DELAY_MAX_US10000.log": "Max Delay = 10s",
}

# plotting
fig, axs = plt.subplots(1, 2, figsize=(14, 6), sharey=True)

# left: sweep probability
for file in prob_files:
    full_path = os.path.join(log_dir, file)
    latencies = load_latencies(full_path)
    if not latencies:
        print(f"⚠️ Warning: {file} is empty or missing")
        continue
    latencies = np.sort(latencies)
    cdf = np.arange(len(latencies)) / len(latencies)
    axs[0].plot(latencies, cdf * 100, label=prob_labels.get(file, file), linewidth=1.3)

axs[0].set_xscale("log")
axs[0].set_xlabel("Latency (µs, log scale)")
axs[0].set_ylabel("CDF (%)")
axs[0].set_title("Injection Probability")
axs[0].grid(True, which="both", linestyle="--", alpha=0.5)
axs[0].legend()

# right: sweep delay
for file in delay_files:
    full_path = os.path.join(log_dir, file)
    latencies = load_latencies(full_path)
    if not latencies:
        print(f"⚠️ Warning: {file} is empty or missing")
        continue
    latencies = np.sort(latencies)
    cdf = np.arange(len(latencies)) / len(latencies)
    axs[1].plot(latencies, cdf * 100, label=delay_labels.get(file, file), linewidth=1.3)

axs[1].set_xscale("log")
axs[1].set_xlabel("Latency (µs, log scale)")
axs[1].set_title("Max Delay (P=20%)")
axs[1].grid(True, which="both", linestyle="--", alpha=0.5)
axs[1].legend()

# save and show
plt.tight_layout()
plt.savefig("latency_cdf_ftcx_side_by_side.png", dpi=300)
plt.show()