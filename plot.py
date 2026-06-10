import pandas as pd
import matplotlib.pyplot as plt
import sys

if len(sys.argv) < 2:
    print("First argument needs to be input csv file from hyperfine output")
    sys.exit(1)

df = pd.read_csv(sys.argv[1])
written = 500_000_000
df["speed"] = df.apply(lambda row: written / row["mean"] , axis=1)

speed_pivot = df.pivot(
    index="parameter_len",
    columns="parameter_memset",
    values="speed",
)
time_pivot = df.pivot(
    index="parameter_len",
    columns="parameter_memset",
    values="mean",
)


ax = speed_pivot.plot(marker="o")
ax.set_title("memset speed")
ax.set_xlabel("Write Length")

ax.set_xscale("log", base=2)
ax.set_xticks(speed_pivot.index)
ax.set_xticklabels([str(x) for x in speed_pivot.index])

ax.set_ylabel("GB / Second")
# ax_yticks = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
# ax.set_yticks([i * 1_000_000_000 for i in ax_yticks])
# ax.set_yticklabels([str(x)  for x in ax_yticks])
ax.grid(True, which="both")

fig = plt.gcf()
fig.set_size_inches(16, 10)
fig.savefig(sys.argv[1] + "_speed.svg")

ax2 = time_pivot.plot(marker="o")
ax2.set_title("Time for memset to write 500MB")

ax2.set_ylabel("Duration (s)")
ax2.set_xlabel("Write Length")

ax2.set_xscale("log", base=2)
ax2.set_xticks(time_pivot.index)
ax2.set_xticklabels([str(x) for x in time_pivot.index])
ax2.grid(True, which="both")

fig = plt.gcf()
fig.set_size_inches(16, 10)
fig.savefig(sys.argv[1] + "_duration.svg")

plt.show()
