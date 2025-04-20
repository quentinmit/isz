import os
import os.path
import sys

from influxdb_client import Point

ROOT = "/sys/class/power_supply"
TAGS = {
    "name",
    "type",
    "technology",
    "scope",
    "model_name",
    "manufacturer",
    "serial_number",
}

for line in sys.stdin:
    for device in os.listdir(ROOT):
        p = Point("power_supply")
        for line in open(os.path.join(ROOT, device, "uevent")):
            name, value = line.strip().split("=", 1)
            name = name.lower().removeprefix("power_supply_")
            if name == "devtype":
                continue
            if name in TAGS:
                p = p.tag(name, value)
                continue
            try:
                p = p.field(name, int(value))
            except ValueError:
                p = p.field(name, value)
        print(p)
    sys.stdout.flush()
