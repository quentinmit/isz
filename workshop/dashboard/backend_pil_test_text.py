#!/usr/bin/env python3

import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.offsetbox
import numpy as np
import logging

logging.basicConfig(level=logging.DEBUG)

matplotlib.offsetbox.DEBUG = True

mpl.use("module://backend_pil")

fig = plt.figure(figsize=(8, 5))
ha_list = ["left", "center", "right"]
va_list = ["top", "center", "baseline", "bottom"]
axs = np.empty((len(va_list), len(ha_list)), object)
gs = fig.add_gridspec(*axs.shape, hspace=0, wspace=0)
axs[0, 0] = fig.add_subplot(gs[0, 0])
for i in range(len(va_list)):
    for j in range(len(ha_list)):
        if (i, j) == (0, 0):
            continue  # Already set.
        axs[i, j] = fig.add_subplot(
            gs[i, j], sharex=axs[0, 0], sharey=axs[0, 0])
for ax in axs.flat:
    ax.set(aspect=1)

# labels and title
for ha, ax in zip(ha_list, axs[-1, :]):
    ax.set_xlabel(ha)
for va, ax in zip(va_list, axs[:, 0]):
    ax.set_ylabel(va)

kw = {"bbox": dict(boxstyle="square,pad=0.", ec="none", fc="C1", alpha=0.3)}

# use a different text alignment in each axes
for i, va in enumerate(va_list):
    for j, ha in enumerate(ha_list):
        ax = axs[i, j]
        # prepare axes layout
        ax.set(xticks=[], yticks=[])
        ax.axvline(0.5, color="skyblue", zorder=0)
        ax.axhline(0.5, color="skyblue", zorder=0)
        ax.plot(0.5, 0.5, color="C0", marker="o", zorder=1)
        # add text with rotation and alignment settings
        tx = ax.text(0.5, 0.5, " Tpg",
                     size="x-large",
                     fontfamily='knxt',
                     horizontalalignment=ha, verticalalignment=va,
                     **kw)

fig.savefig("test.pbm")
import io
w = io.BytesIO()
fig.savefig(w, format='pbm')
print(len(w.getvalue()))
plt.show()
