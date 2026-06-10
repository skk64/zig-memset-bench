import pandas as pd
import matplotlib.pyplot as plt
import sys

df = pd.read_csv(sys.argv[1])
written = 500_000_000
df["speed"] = df.apply(lambda row: written / row["mean"] , axis=1)

pivot = df.pivot(
    index="parameter_len",
    columns="parameter_memset",
    values="speed",
)

ax = pivot.plot(marker="o")
ax.set_title("Write Length")
ax.set_xlabel("Write Length")
ax.set_ylabel("GB / Second")

ax.set_xscale("log", base=2)
ax.set_xticks(pivot.index)
ax.set_xticklabels([str(x) for x in pivot.index])

yticks = [0, 0.5, 1, 1.5, 2, 2.5]
ax.set_yticks([i * 1_000_000_000 for i in yticks])
ax.set_yticklabels([str(x)  for x in yticks])

ax.grid(True, which="both")  # optional: grid for log scale
plt.show()
