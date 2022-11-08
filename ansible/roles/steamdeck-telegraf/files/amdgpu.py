#!/usr/bin/env python3

from typing import List
import glob
import os.path
import ctypes
from collections import defaultdict
import subprocess
import shlex
import sys
import time
import threading

class c_uint8(ctypes.c_uint8): pass
class c_uint16(ctypes.c_uint16): pass
class c_uint32(ctypes.c_uint32): pass
class c_uint64(ctypes.c_uint64): pass

class BaseStructure(ctypes.Structure):
    def __str__(self):
        result = []
        result.append("struct {0} {{".format(self.__class__.__name__))
        for field in self._fields_:
            attr, attrType = field[:2]
            value = getattr(self, attr)
            if isinstance(value, ctypes.Array):
                value = list(value)
            value = repr(value)
            if not value.endswith(';'):
                value += ';'
            value = '\n'.join(('    ' if i else '')+l for i, l in enumerate(value.splitlines()))
            result.append("    {0} [{1}] = {2}".format(attr, attrType.__name__, value))
        result.append("};")
        return '\n'.join(result)

    __repr__ = __str__

# Translated from structs in https://elixir.bootlin.com/linux/latest/source/drivers/gpu/drm/amd/include/kgd_pp_interface.h

class metrics_table_header(BaseStructure):
    _fields_ = [
	    ("structure_size", c_uint16),
	    ("format_revision", c_uint8),
	    ("content_revision", c_uint8),
    ]

NUM_HBM_INSTANCES = 4

# gpu_metrics_v1_0 is not recommended as it's not naturally aligned.
# Use gpu_metrics_v1_1 or later instead.

class gpu_metrics_v1_0(BaseStructure):
    _fields_ = [
        ("common_header", metrics_table_header),

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Temperature
	    ("temperature_edge", c_uint16),
	    ("temperature_hotspot", c_uint16),
	    ("temperature_mem", c_uint16),
	    ("temperature_vrgfx", c_uint16),
	    ("temperature_vrsoc", c_uint16),
	    ("temperature_vrmem", c_uint16),

	    # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_umc_activity", c_uint16), # memory controller
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Power/Energy
	    ("average_socket_power", c_uint16),
	    ("energy_accumulator", c_uint32),

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_vclk0_frequency", c_uint16),
	    ("average_dclk0_frequency", c_uint16),
	    ("average_vclk1_frequency", c_uint16),
	    ("average_dclk1_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_vclk0", c_uint16),
	    ("current_dclk0", c_uint16),
	    ("current_vclk1", c_uint16),
	    ("current_dclk1", c_uint16),

	    # Throttle status
	    ("throttle_status", c_uint32),

	    # Fans
	    ("current_fan_speed", c_uint16),

	    # Link width/speed
	    ("pcie_link_width", c_uint8),
	    ("pcie_link_speed", c_uint8), # in 0.1 GT/s
    ]


class gpu_metrics_v1_1(BaseStructure):
    _fields_ = [
	    ("common_header", metrics_table_header),

	    # Temperature
	    ("temperature_edge", c_uint16),
	    ("temperature_hotspot", c_uint16),
	    ("temperature_mem", c_uint16),
	    ("temperature_vrgfx", c_uint16),
	    ("temperature_vrsoc", c_uint16),
	    ("temperature_vrmem", c_uint16),

	    # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_umc_activity", c_uint16), # memory controller
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Power/Energy
	    ("average_socket_power", c_uint16),
	    ("energy_accumulator", c_uint64),

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_vclk0_frequency", c_uint16),
	    ("average_dclk0_frequency", c_uint16),
	    ("average_vclk1_frequency", c_uint16),
	    ("average_dclk1_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_vclk0", c_uint16),
	    ("current_dclk0", c_uint16),
	    ("current_vclk1", c_uint16),
	    ("current_dclk1", c_uint16),

	    # Throttle status
	    ("throttle_status", c_uint32),

	    # Fans
	    ("current_fan_speed", c_uint16),

	    # Link width/speed
	    ("pcie_link_width", c_uint16),
	    ("pcie_link_speed", c_uint16), # in 0.1 GT/s

	    ("padding", c_uint16),

	    ("gfx_activity_acc", c_uint32),
	    ("mem_activity_acc", c_uint32),

	    ("temperature_hbm", c_uint16, NUM_HBM_INSTANCES),
    ]


class gpu_metrics_v1_2(BaseStructure):
    _fields_ = [
	    ("common_header", metrics_table_header),

	    # Temperature
	    ("temperature_edge", c_uint16),
	    ("temperature_hotspot", c_uint16),
	    ("temperature_mem", c_uint16),
	    ("temperature_vrgfx", c_uint16),
	    ("temperature_vrsoc", c_uint16),
	    ("temperature_vrmem", c_uint16),

	    # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_umc_activity", c_uint16), # memory controller
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Power/Energy
	    ("average_socket_power", c_uint16),
	    ("energy_accumulator", c_uint64),

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_vclk0_frequency", c_uint16),
	    ("average_dclk0_frequency", c_uint16),
	    ("average_vclk1_frequency", c_uint16),
	    ("average_dclk1_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_vclk0", c_uint16),
	    ("current_dclk0", c_uint16),
	    ("current_vclk1", c_uint16),
	    ("current_dclk1", c_uint16),

	    # Throttle status (ASIC dependent)
	    ("throttle_status", c_uint32),

	    # Fans
	    ("current_fan_speed", c_uint16),

	    # Link width/speed
	    ("pcie_link_width", c_uint16),
	    ("pcie_link_speed", c_uint16), # in 0.1 GT/s

	    ("padding", c_uint16),

	    ("gfx_activity_acc", c_uint32),
	    ("mem_activity_acc", c_uint32),

	    ("temperature_hbm", c_uint16 * NUM_HBM_INSTANCES),

	    # PMFW attached timestamp (10ns resolution)
	    ("firmware_timestamp", c_uint64),
    ]


class gpu_metrics_v1_3(BaseStructure):
    _fields_ = [
	    ("common_header", metrics_table_header),

	    # Temperature
	    ("temperature_edge", c_uint16),
	    ("temperature_hotspot", c_uint16),
	    ("temperature_mem", c_uint16),
	    ("temperature_vrgfx", c_uint16),
	    ("temperature_vrsoc", c_uint16),
	    ("temperature_vrmem", c_uint16),

	    # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_umc_activity", c_uint16), # memory controller
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Power/Energy
	    ("average_socket_power", c_uint16),
	    ("energy_accumulator", c_uint64),

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_vclk0_frequency", c_uint16),
	    ("average_dclk0_frequency", c_uint16),
	    ("average_vclk1_frequency", c_uint16),
	    ("average_dclk1_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_vclk0", c_uint16),
	    ("current_dclk0", c_uint16),
	    ("current_vclk1", c_uint16),
	    ("current_dclk1", c_uint16),

	    # Throttle status
	    ("throttle_status", c_uint32),

	    # Fans
	    ("current_fan_speed", c_uint16),

	    # Link width/speed
	    ("pcie_link_width", c_uint16),
	    ("pcie_link_speed", c_uint16), # in 0.1 GT/s

	    ("padding", c_uint16),

	    ("gfx_activity_acc", c_uint32),
	    ("mem_activity_acc", c_uint32),

	    ("temperature_hbm", c_uint16 * NUM_HBM_INSTANCES),

	    # PMFW attached timestamp (10ns resolution)
	    ("firmware_timestamp", c_uint64),

	    # Voltage (mV)
	    ("voltage_soc", c_uint16),
	    ("voltage_gfx", c_uint16),
	    ("voltage_mem", c_uint16),

	    ("padding1", c_uint16),

	    # Throttle status (ASIC independent)
	    ("indep_throttle_status", c_uint64),
    ]

# gpu_metrics_v2_0 is not recommended as it's not naturally aligned.
# Use gpu_metrics_v2_1 or later instead.

class gpu_metrics_v2_0(BaseStructure):
    _fields_ = [
	    ("common_header", metrics_table_header),

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Temperature
	    ("temperature_gfx", c_uint16), # gfx temperature on APUs
	    ("temperature_soc", c_uint16), # soc temperature on APUs
	    ("temperature_core", c_uint16 * 8), # CPU core temperature on APUs
	    ("temperature_l3", c_uint16 * 2),

	    # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Power/Energy
	    ("average_socket_power", c_uint16), # dGPU + APU power on A + A platform
	    ("average_cpu_power", c_uint16),
	    ("average_soc_power", c_uint16),
	    ("average_gfx_power", c_uint16),
	    ("average_core_power", c_uint16 * 8), # CPU core power on APUs

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_fclk_frequency", c_uint16),
	    ("average_vclk_frequency", c_uint16),
	    ("average_dclk_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_fclk", c_uint16),
	    ("current_vclk", c_uint16),
	    ("current_dclk", c_uint16),
	    ("current_coreclk", c_uint16 * 8), # CPU core clocks
	    ("current_l3clk", c_uint16 * 2),

	    # Throttle status
	    ("throttle_status", c_uint32),

	    # Fans
	    ("fan_pwm", c_uint16),

	    ("padding", c_uint16),
    ]


class gpu_metrics_v2_1(BaseStructure):
    _fields_ = [
	    ("common_header", metrics_table_header),

	    # Temperature
	    ("temperature_gfx", c_uint16), # gfx temperature on APUs
	    ("temperature_soc", c_uint16), # soc temperature on APUs
	    ("temperature_core", c_uint16 * 8), # CPU core temperature on APUs
	    ("temperature_l3", c_uint16 * 2),

	    # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Power/Energy
	    ("average_socket_power", c_uint16), # dGPU + APU power on A + A platform
	    ("average_cpu_power", c_uint16),
	    ("average_soc_power", c_uint16),
	    ("average_gfx_power", c_uint16),
	    ("average_core_power", c_uint16 * 8), # CPU core power on APUs

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_fclk_frequency", c_uint16),
	    ("average_vclk_frequency", c_uint16),
	    ("average_dclk_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_fclk", c_uint16),
	    ("current_vclk", c_uint16),
	    ("current_dclk", c_uint16),
	    ("current_coreclk", c_uint16 * 8), # CPU core clocks
	    ("current_l3clk", c_uint16 * 2),

	    # Throttle status
	    ("throttle_status", c_uint32),

	    # Fans
	    ("fan_pwm", c_uint16),

	    ("padding", c_uint16 * 3),
    ]


class gpu_metrics_v2_2(BaseStructure):
    _fields_ = [
	    ("common_header", metrics_table_header),

	    # Temperature
	    ("temperature_gfx", c_uint16), # gfx temperature on APUs
	    ("temperature_soc", c_uint16), # soc temperature on APUs
	    ("temperature_core", c_uint16 * 8), # CPU core temperature on APUs
	    ("temperature_l3", c_uint16 * 2),

        # Utilization
	    ("average_gfx_activity", c_uint16),
	    ("average_mm_activity", c_uint16), # UVD or VCN

	    # Driver attached timestamp (in ns)
	    ("system_clock_counter", c_uint64),

	    # Power/Energy
	    ("average_socket_power", c_uint16), # dGPU + APU power on A + A platform
	    ("average_cpu_power", c_uint16),
	    ("average_soc_power", c_uint16),
	    ("average_gfx_power", c_uint16),
	    ("average_core_power", c_uint16 * 8), # CPU core power on APUs

	    # Average clocks
	    ("average_gfxclk_frequency", c_uint16),
	    ("average_socclk_frequency", c_uint16),
	    ("average_uclk_frequency", c_uint16),
	    ("average_fclk_frequency", c_uint16),
	    ("average_vclk_frequency", c_uint16),
	    ("average_dclk_frequency", c_uint16),

	    # Current clocks
	    ("current_gfxclk", c_uint16),
	    ("current_socclk", c_uint16),
	    ("current_uclk", c_uint16),
	    ("current_fclk", c_uint16),
	    ("current_vclk", c_uint16),
	    ("current_dclk", c_uint16),
	    ("current_coreclk", c_uint16 * 8), # CPU core clocks
	    ("current_l3clk", c_uint16 * 2),

	    # Throttle status (ASIC dependent)
	    ("throttle_status", c_uint32),

	    # Fans
	    ("fan_pwm", c_uint16),

	    ("padding", c_uint16 * 3),

	    # Throttle status (ASIC independent)
	    ("indep_throttle_status", c_uint64),
    ]

METRICS_POLLING_PERIOD_MS = 5

FORMATS = {
    (1, 0): gpu_metrics_v1_0,
    (1, 1): gpu_metrics_v1_1,
    (1, 2): gpu_metrics_v1_2,
    (1, 3): gpu_metrics_v1_3,
    (2, 0): gpu_metrics_v2_0,
    (2, 1): gpu_metrics_v2_1,
    (2, 2): gpu_metrics_v2_2,
}

LSPCI_KEYS = "slot class vendor_name device_name subsystem_vendor_name subsystem_name".split()

def lspci_info(slot: str) -> dict:
    line = subprocess.check_output(["lspci", "-s", slot, "-mm"]).decode('utf-8')
    parts = shlex.split(line)
    arg_parts = {p[1]: p[2:] for p in parts if p.startswith('-')}
    pos_parts = dict(zip(LSPCI_KEYS, (p for p in parts if not p.startswith('-'))))
    return pos_parts | arg_parts

def parse_struct(data: bytes) -> BaseStructure:
    header = metrics_table_header.from_buffer_copy(data[:ctypes.sizeof(metrics_table_header)])

    if header.structure_size.value != len(data):
        raise ValueError("unexpected data length %d, expected %d" % (len(data), header.structure_size.value))

    cls = FORMATS[(header.format_revision.value, header.content_revision.value)]
    return cls.from_buffer_copy(data)

def find_files() -> List[str]:
    return set(os.path.realpath(p) for p in glob.glob("/sys/class/drm/*/device/gpu_metrics"))

def tag_str(tags: dict) -> str:
    return ','.join('%s=%s' % (k, str(v).replace("\\", "\\\\").replace(" ", r"\ ").replace(",", r"\,")) for k,v in tags.items())

def debug_main():
    files = find_files()
    for f in files:
        slot = os.path.basename(os.path.dirname(f))
        tags = lspci_info(slot)
        metrics = parse_struct(open(f, 'rb').read())

        print(slot, tags, metrics)

class GPU:
    def __init__(self, path):
        self.path = path
        self.file = open(path, 'rb')
        slot = os.path.basename(os.path.dirname(self.path))
        self.tags = lspci_info(slot)
        self._lock = threading.Lock()
        self.samples = []

    def sample(self):
        self.file.seek(0)
        metrics = parse_struct(self.file.read())
        with self._lock:
            self.samples.append(metrics)

    def average(self) -> tuple[int, dict[tuple, float]]:
        with self._lock:
            samples = self.samples
            self.samples = []
        intermediate = defaultdict(list)
        def add(attr, value, extra=tuple()):
            if isinstance(value, ctypes._SimpleCData):
                if value.value == value.__class__(-1).value:
                    return
                intermediate[(attr,) + extra].append(value.value)
            elif isinstance(value, ctypes.Array):
                for i, v in enumerate(value):
                    add(attr, v, extra=(i,))
        # TODO: Use system_clock_counter to weight samples
        # TODO: Don't average *throttle_status
        for metrics in samples:
            for field in metrics._fields_:
                attr, attrType = field[:2]
                value = getattr(metrics, attr)
                add(attr, value)
        out = {}
        for attr, values in intermediate.items():
            out[attr] = sum(values) / len(values)
        return len(samples), out

def debug_average_main():
    path = next(iter(find_files()))
    g = GPU(path)
    for i in range(100):
        g.sample()
        time.sleep(METRICS_POLLING_PERIOD_MS * 0.001)
    print(g.average())

def scrape_metrics():
    files = find_files()
    for f in files:
        slot = os.path.basename(os.path.dirname(f))
        tags = lspci_info(slot)
        metrics = parse_struct(open(f, 'rb').read())
        out_measurements = defaultdict(dict)

        def add(key, value, **extra_tags):
            if isinstance(value, ctypes._SimpleCData):
                if value.value == value.__class__(-1).value:
                    return
                value = value.value
            else:
                return
            out_measurements[tag_str(tags | extra_tags)][key] = value

        for field in metrics._fields_:
            attr, attrType = field[:2]
            value = getattr(metrics, attr)
            if isinstance(value, ctypes.Array):
                for i, v in enumerate(value):
                    add(attr, v, index=i)
                continue
            add(attr, value)

        for tags, fields in out_measurements.items():
            print("amdgpu,%s %s %d" % (
                tags,
                ",".join(
                    "%s=%di" % (k,v)
                    for k,v in fields.items()
                ),
                int(time.time()*1e9)
            ))

def main():
    for line in sys.stdin:
        scrape_metrics()

def threaded_main():
    gpus = []
    for f in find_files():
        gpus.append(GPU(f))

    def loop():
        while True:
            for g in gpus:
                g.sample()
            time.sleep(METRICS_POLLING_PERIOD_MS * 0.001)

    t = threading.Thread(target=loop, daemon=True)
    t.start()

    for line in sys.stdin:
        for g in gpus:
            samples, data = g.average()
            if not data:
                continue
            tags = tag_str(g.tags)
            out = defaultdict(dict)
            for key, value in data.items():
                if len(key) > 1:
                    out[',index=%d' % (key[1],)][key[0]] = value
                else:
                    out[''][key[0]] = value
            for extra_tags, fields in out.items():
                print("amdgpu_hires,%s%s %s %d" % (
                    tags, extra_tags,
                    ",".join(
                        "%s=%f" % (k,v)
                        for k,v in fields.items()
                    ),
                    int(time.time()*1e9)
                ))
            print("amdgpu_hires,%s _samples=%di" % (tags, samples))

if __name__ == '__main__':
    threaded_main()
