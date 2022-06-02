#!/usr/bin/python3
from influxdb_client import Point
import asyncio
import argparse
import functools
import httpx
import itertools
from more_itertools import chunked
import logging
import sys
import time
from typing import Iterable
from pyparsing import Combine, Word, hexnums, alphas, alphanums, dictOf, QuotedString, Forward, Group, Optional, Suppress, delimitedList, ParseException


class MyPoint(Point):
    def tags(self, tags: dict):
        for name, value in tags.items():
            self.tag(name, value)
        return self
    def fields(self, fields: dict):
        for name, value in fields.items():
            self.field(name, value)
        return self

# "bool" means it's a single number as bitmask

FIELDS = {
    "link.b": {
        "en": { # Enabled
            "name": "enabled",
            "type": "bool",
        },
        "nm": { # Name
            "name": "if-name",
            "tag": True
        },
        "lnk": { # Link Status
            "name": "running",
            "type": "bool",
        },
        "an": { # Auto Negotiation
            "name": "auto-negotiation",
            "type": "bool",
        },
        "spdc": {
            "name": "advertised-speed",
            "type": "enum",
            "values": [10, 100, 1000],
        },
        "spd": {
            "name": "speed",
            "type": "enum",
            "values": [10, 100, 1000, None],
        },
        "dpxc": {
            "name": "advertised-full-duplex",
            "type": "bool",
        },
        "dpx": {
            "name": "full-duplex",
            "type": "bool",
        },
        "fct": {
            "name": "flow-control",
            "type": "bool",
        },
        "poe": {
            "name": "poe-out",
            "type": "enum",
            "values": ["off", "auto", "on", "calibr"],
        },
        "prio": {
            "name": "poe-priority",
            "type": "enum",
            "values": [1, 2, 3, 4],
        },
        "poes": {
            "name": "poe-status",
            "type": "enum",
            "values": [None, "disabled", "waiting for load", "powered on", "overload", "short circuit", "voltage too low", "current too low", "power cycle", "voltage too high", "controller error"],
        },
        "curr": {
            "name": "poe-current",
        },
        "pwr": {
            "name": "poe-power",
            "scale": 10,
        },
    },
    # TODO: sfp.b
    "fwd.b": {
        # fp1-fp6 From Port 1-6 bool
        # lck Port Lock
        # lckf Lock On First
        # imr Mirror Ingress bool
        # omr Mirror Egress bool
        # mrto Mirror To index
        # or Egress Rate
        "vlan": {
            "name": "vlan-mode",
            "type": "enum",
            "values": ["disabled", "optional", "enabled", "strict"],
        },
        "vlni": {
            "name": "vlan-receive",
            "type": "enum",
            "values": ["any", "only tagged", "only untagged"],
        },
        "dvid": {
            "name": "default-vlan-id",
            "tag": True,
        },
        "fvid": {
            "name": "force-vlan-id",
            "type": "bool",
        },
        "vlnh": {
            "name": "vlan-header",
            "type": "enum",
            "values": ["leave as is", "always strip", "add if missing"],
        },
    },
    "rstp.b": {
        "ena": {
            "name": "rstp-enabled",
            "type": "bool",
        },
        "rstp": {
            "name": "rstp-rapid",
            "type": "bool",
        },
        "role": {
            "name": "rstp-role",
            "type": "enum",
            "values": ["disabled", "alternate", "root", "designated", "backup"],
        },
        "rpc": {
            "name": "rstp-root-path-cost",
        },
        "p2p": {
            "name": "rstp-type",
            "type": "dual-bool",
            "second": "edge",
            "values": ["shared", "point-to-point", "edge", "edge"],
            "tag": True,
        },
        "lrn": {
            "name": "rstp-state",
            "type": "dual-bool",
            "second": "fwd",
            "values": ["discarding", "learning", "forwarding", "forwarding"],
        },
        # cst Unknown
    },
    "!stats.b": {
        # Stats
        'rrb': {'name': 'rx-rate', 'scale': 0.08},
        'rrp': {'name': 'rx-packet-rate', 'scale': 0.64},
        'trb': {'name': 'tx-rate', 'scale': 0.08},
        'trp': {'name': 'tx-packet-rate', 'scale': 0.64},
        'rb': {'name': 'rx-bytes'},
        'rtp': {'name': 'rx-packets'},
        'rup': {'name': 'rx-unicasts'},
        'rbp': {'name': 'rx-broadcasts'},
        'rmp': {'name': 'rx-multicasts'},
        'r64': {'name': 'rx-64'},
        'r65': {'name': 'rx-65-127'},
        'r128': {'name': 'rx-128-255'},
        'r256': {'name': 'rx-256-511'},
        'r512': {'name': 'rx-512-1023'},
        'r1k': {'name': 'rx-1024-1518'},
        'rmax': {'name': 'rx-1519-max'},
        'tb': {'name': 'tx-bytes'},
        'ttp': {'name': 'tx-packets'},
        'tup': {'name': 'tx-unicasts'},
        'tbp': {'name': 'tx-broadcasts'},
        'tmp': {'name': 'tx-multicasts'},
        't64': {'name': 'tx-64'},
        't65': {'name': 'tx-65-127'},
        't128': {'name': 'tx-128-255'},
        't256': {'name': 'tx-256-511'},
        't512': {'name': 'tx-512-1023'},
        't1k': {'name': 'tx-1024-1518'},
        'tmax': {'name': 'tx-1519-max'},
        # Errors
        # RX
        'rpp': {'name': 'rx-pause'},
        'rte': {'name': 'rx-total-error'},
        'rfcs': {'name': 'rx-fcs-error'},
        'rae': {'name': 'rx-align-error'},
        'rr': {'name': 'rx-runt'},
        'fr': {'name': 'rx-fragment'},
        'rtl': {'name': 'rx-too-long'},
        'rov': {'name': 'rx-overflow'},
        # TX
        'tpp': {'name': 'tx-pause'},
        'tte': {'name': 'tx-total-error'},
        'tur': {'name': 'tx-underrun'},
        'ttl': {'name': 'tx-too-long'},
        'tcl': {'name': 'tx-collision'},
        'tec': {'name': 'tx-excessive-collision'},
        'tmc': {'name': 'tx-multiple-collision'},
        'tsc': {'name': 'tx-single-collision'},
        'ted': {'name': 'tx-excessive-deferred'},
        'tdf': {'name': 'tx-deferred'},
        'tlc': {'name': 'tx-late-collision'}
    },
    # TODO: vlan.b
    # TODO: host.b
    # TODO: !igmp.b
    # TODO: snmp.b
    # TODO: acl.b
    "sys.b": {
        # prio Bridge Priority (hex)
        # cost Port Cost Mode [short, long]
        # rpr.rmac Root Bridge
        # iptp Address Acquisition
        # sip Static IP Address
        # id Identity
        # alla allm Allow From
        # allp Allow From Ports
        # avln Allow From VLAN
        # wdt Watchdog
        # ivl Independent VLAN Lookup
        # igmp IGMP Snooping
        # dsc Mikrotik Discovery Protocol
        # lcbl Port1 PoE In Long Cable
        # mac MAC Address
        # sid Serial Number
        # brd Board Name
        # volt Voltage
        # temp Temperature
    },
}

def parse_js(text: str) -> object:
    """Parse JavaScript text (not valid JSON, unfortunately) into a Python data structure."""
    number = Combine("0x" + Word(hexnums)).setParseAction(lambda toks: int(toks[0], 16))
    qs = QuotedString("'").setParseAction(
        lambda toks: bytes(
            map(
                lambda i: int(''.join(i), 16),
                chunked(toks[0], 2)
            )
        )
    )
    array = Forward()
    obj = Forward()
    value = (number | qs | array | obj)
    array << Group(Suppress("[") + Optional(delimitedList(value)) + Suppress("]"))
    key = Word(alphas, alphanums)
    obj << (
        Suppress("{") + dictOf(Suppress(Optional(",")) + key + Suppress(":"), value) + Suppress("}")
    ).setParseAction(lambda toks: toks.asDict())
    try:
        return value.parseString(text).asList()[0]
    except ParseException:
        logging.exception("failed to parse %s", text)
        raise

def merge_64bit(stats: dict) -> dict:
    keys = set(stats.keys())
    keys_high = set(k+'h' for k in keys) & keys
    for k in keys_high:
        stats[k[:-1]] = [v1 | ((0 if v2 == 0xffffffff else v2) << 32) for v1, v2 in zip(stats[k[:-1]], stats[k])]
        del stats[k]
    return stats

def format(data: dict, id: str, desc: dict) -> object:
    value = data[id]
    type = desc.get("type")
    if type == "bool":
        value = [value & (1 << i) != 0 for i in range(6)]
    elif type == "enum":
        value = [desc["values"][v] if v < len(desc["values"]) else v for v in value]
    elif type == "dual-bool":
        value2 = data[desc["second"]]
        value = [((value2 & (1 << i)) >> i << 1) | ((value & (1 << i)) >> i) for i in range(6)]
        value = [desc["values"][v] for v in value]
    if isinstance(value[0], bytes):
        value = [v.decode('utf-8') for v in value]
    if "scale" in desc:
        value = [v / desc["scale"] for v in value]
    return value


async def main():
    parser = argparse.ArgumentParser(description='Extract edgeos metrics.')
    parser.add_argument('--server', metavar='IP', required=True,
                        help='edgeos server to scrape')
    parser.add_argument('--user', metavar='USER', required=True,
                        help='username')
    parser.add_argument('--password', metavar='PASSWORD', required=True,
                        help='password')
    parser.add_argument('--verbose', action='store_true')

    args = parser.parse_args()

    logging.basicConfig(level=logging.NOTSET if args.verbose else logging.INFO)

    auth = httpx.DigestAuth(args.user, args.password)
    async with httpx.AsyncClient() as client:
        async def get(path: str) -> object:
            r = await client.get(f'http://{args.server}/{path}', auth=auth)
            return merge_64bit(parse_js(r.text))
        async def get_interface_metrics() -> (dict, Iterable):
            tasks = set()
            for k in FIELDS:
                tasks.add(asyncio.create_task(get(k), name=k))
            await asyncio.wait(tasks)
            data = {}
            for task in tasks:
                data[task.get_name()] = task.result()

            interface_tags = [{} for i in range(6)]
            interface_fields = [{} for i in range(6)]
            for section, fields in FIELDS.items():
                section_data = data[section]
                for id, field in fields.items():
                    if id in section_data:
                        try:
                            values = format(section_data, id, field)
                        except:
                            logging.exception("failed to parse %s", id)
                            raise
                        interfaces = interface_fields
                        if field.get('tag'):
                            interfaces = interface_tags
                        for i, v in enumerate(values):
                            interfaces[i][field['name']] = v
            for i in interface_fields:
                # Hack alert!
                if i['auto-negotiation']:
                    i['advertised-speed'] = 1000
            return data, zip(interface_tags, interface_fields)

        for line in sys.stdin:
            t = time.time_ns()
            data, interfaces = await get_interface_metrics()
            logging.debug("got data %r", data)

            def point(measurement):
                return MyPoint(measurement) \
                    .time(t) \
                    .tag("agent_host", args.server) \
                    .tag("hostname", data["sys.b"]["id"].decode('utf-8'))
            print(
                point("swos").field("voltage", data["sys.b"]["volt"]/10).field("temperature", float(data["sys.b"]["temp"])).to_line_protocol()
            )
            for tags, fields in interfaces:
                p = point("swos-interfaces")
                p.tags(tags)
                p.fields(fields)
                print(p.to_line_protocol())


if __name__ == "__main__":
    asyncio.run(main())
