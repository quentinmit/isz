import os
import os.path
import sys
import time
import re

from influxdb_client import Point

ROOT = "/sys/class/drm"
CARD_RE = re.compile(r'^card(\d+)$')
FIELDS = {
    "current_link_speed",
    "current_link_width",
    "max_link_speed",
    "max_link_width",
    "gpu_busy_percent",
    "mem_info_gtt_total",
    "mem_info_gtt_used",
    "mem_info_preempt_used",
    "mem_info_vis_vram_total",
    "mem_info_vis_vram_used",
    "mem_info_vram_total",
    "mem_info_vram_used",
}

for line in sys.stdin:
    for card in os.listdir(ROOT):
        m = CARD_RE.match(card)
        if not m:
            continue
        p = Point("drm")
        p.tag("card", m.group(1))
        device = os.path.join(ROOT, card, "device")
        for line in open(os.path.join(device, "uevent")):
            name, value = line.strip().split("=", 1)
            p.tag(name.lower(), value.strip())

        for field in FIELDS:
            try:
                with open(os.path.join(device, field)) as f:
                    value = f.read().strip()
            except OSError:
                continue
            try:
                value = int(value)
            except ValueError:
                pass
            p.field(field, value)
        print(
            p
            .time(time.time_ns())
            .to_line_protocol()
        )
    sys.stdout.flush()
