import pandas as pd
import matplotlib.pyplot as plt
import sys

df = pd.read_csv(sys.argv[1])
written = 500000000

df["gbps"] = df.apply(lambda row: written / row["mean"] * 1_000_000, axis=1)

pivot = df.pivot(
    index="parameter_len",
    columns="parameter_memset",
    values="mbps",
)

pivot.plot(marker="o")

# plt.xlabel("parameter_len")
# plt.ylabel("mean")
# plt.title("Mean by parameter_len")
# plt.yscale("log") 
# plt.xscale("log") 

ax = pivot.plot(marker="o")
# ax.set_xlabel("Write Length")
ax.set_xscale("log", base=2)
ax.set_xticks(pivot.index)
ax.set_xticklabels([str(x) for x in pivot.index])

ax.grid(True, which="both")  # optional: grid for log scale
plt.show()
