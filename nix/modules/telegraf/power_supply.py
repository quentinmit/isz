import os
import os.path
import sys
import time
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
        result = {}
        for line in open(os.path.join(ROOT, device, "uevent")):
            name, value = line.strip().split("=", 1)
            name = name.split("_", 2)[2].lower()
            if name in TAGS:
                device += ",%s=%s" % (name, value)
                continue
            try:
                int(value)
            except ValueError:
                value = '"%s"' % value
            else:
                value = '%si' % value
            result[name] = value
        print(
            "power_supply,device=%s %s %d" % (
                device,
                ",".join(
                    "%s=%s" % (k, v)
                    for k, v in result.items()
                ),
                int(time.time()*1e9)
            )
        )
    sys.stdout.flush()
