import os
import os.path
import sys
import time
ROOT = "/sys/class/powercap"
last_result_by_device = {}
for line in sys.stdin:
    for device in os.listdir(ROOT):
        result = {}
        last_result = last_result_by_device.get(device, {})
        for de in os.scandir(os.path.join(ROOT, device)):
            if not de.is_file():
                continue
            try:
                result[de.name] = open(de.path).read().strip()
            except OSError:
                pass
        tags = "device=%s" % (device,)
        if "name" in result:
            tags += ",name=%s" % (result["name"])
            del result["name"]
        result = {k: int(v) for k, v in result.items() if v != ""}
        if "energy_uj" in result:
            energy_uj = result["energy_uj"]
            last_energy_uj = last_result.get("energy_uj", 0)
            if energy_uj < last_energy_uj:
                energy_uj += result.get("max_energy_range_uj", 0)
            result["energy_uj_cumulative"] = (
                last_result.get("energy_uj_cumulative", 0)
                + (energy_uj - last_energy_uj)
            )
            if result["energy_uj_cumulative"] > 0x7fffffffffffffff:
                # Wrap at 2^63
                result["energy_uj_cumulative"] = 0
        print("intel_rapl,%s %s %d" % (
            tags,
            ",".join(
                "%s=%di" % (k, v)
                for k, v in result.items()
                if v
            ),
            int(time.time()*1e9)
        ))
        last_result_by_device[device] = result
    sys.stdout.flush()
