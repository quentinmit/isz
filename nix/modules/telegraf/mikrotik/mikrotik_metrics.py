#!/usr/bin/python3
from influxdb_client import Point
import asyncio
import argparse
import abc
from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, field
import functools
import io
import logging
import re
import sys
import time
import routeros_api


class MyPoint(Point):
    def tags(self, tags: dict):
        for key, value in tags.items():
            self.tag(key, value)
        return self

    def fields(self, fields: dict):
        for name, value in fields.items():
            self.field(name, value)
        return self

    def clone_with_tags(self):
        return type(self)(self._name).tags(self._tags).time(self._time, write_precision=self._write_precision)

def to_int(base, value):
    return {base: int(value)}

def to_txrx(base, value):
    tx, rx = value.split(',')
    return {
        'tx-'+base: int(tx),
        'rx-'+base: int(rx),
    }

def to_bool(base: str, value: str):
    try:
        return {base: {
            'true': True,
            'false': False,
        }[value]}
    except KeyError:
        raise ValueError("not bool")

def to_rate(base: str, value: str):
    if base != "rate" and not base.endswith("-rate"):
        raise ValueError("not rate")
    d = {
        base+"-name": value,
    }
    parts = value.split("-", 1)
    num = parts[0]
    if num.endswith("Mbps"):
        d[base] = int(float(num[:-4])*1e6)
    if num.endswith("Gbps"):
        d[base] = int(float(num[:-4])*1e9)
    return d

def to_channel(base: str, value: str) -> dict:
    freq_bands_mode = value
    if "+" in freq_bands_mode:
        freq_bands_mode = freq_bands_mode.split("+")[0]
    center, bands, mode = freq_bands_mode.split("/")
    center = int(center)
    ret = {
        base+"-name": value,
        base+"-center-frequency": center*1000000,
    }
    try:
        width, bands = bands.split("-")
        width = int(width)
        before, after = bands.split("C")
        lower = center - width * len(before) - (width // 2)
        upper = center + width * len(after) + (width // 2)
        ret.update({
            base+"-lower-frequency": lower*1000000,
            base+"-upper-frequency": upper*1000000,
        })
    except ValueError:
        logging.debug("Unable to parse %s", bands)
    return ret

DURATION_RE = re.compile(r'''
^
(?:(?P<weeks>\d+)w)?
(?:(?P<days>\d+)d)?
(?:(?P<hours>\d+)[:h])?
(?:
  (?P<minutes>\d+):
  (?P<seconds>\d*(?:\.\d{1,9})?)
|
  (?:(?P<minutes2>\d+)m)?
  (?:(?P<seconds2>\d+|\d*\.\d{1,9})s)?
  (?:(?P<ms>\d+|\d*\.\d{1,9})ms)?
  (?:(?P<us>\d+|\d*\.\d{1,9})us)?
  (?:(?P<ns>\d+|\d*\.\d{1,9})ns)?
)
$
''', re.VERBOSE)

def to_duration(base: str, value: str):
    if not value:
        raise ValueError("empty duration")
    m = DURATION_RE.match(value)
    if m:
        seconds = 0
        if v := m.group("weeks"):
            seconds += int(v)*7*24*60*60
        if v := m.group("days"):
            seconds += int(v)*24*60*60
        if v := m.group("hours"):
            seconds += int(v)*60*60
        if v := m.group("minutes"):
            seconds += int(v)*60
        if v := m.group("minutes2"):
            seconds += int(v)*60
        if v := m.group("seconds"):
            seconds += float(v)
        if v := m.group("seconds2"):
            seconds += float(v)
        if v := m.group("ms"):
            seconds += int(v)*1e-3
        if v := m.group("us"):
            seconds += int(v)*1e-6
        if v := m.group("ns"):
            seconds += int(v)*1e-9
        return {
            base + "-ns": int(seconds*1e9),
        }
    raise ValueError("not a duration")

def to_signal(base: str, value: str) -> dict:
    rssi, rate = value.split('@', 1)
    return to_int(base, rssi) | to_rate(base + '-rate', rate)

def to_strength_at_rates(base: str, value: str) -> list:
    parts = value.split(',')
    ret = []
    for part in parts:
        rssi_rate, age = part.split(' ')
        rssi, rate = rssi_rate.split('@')
        ret.append((
            {'rate': rate},
            to_int(base, rssi) | to_duration(base+"-age", age)
        ))
    return ret

def to_current_tx_powers(base: str, value: str) -> list:
    parts = value.split(',')
    ret = []
    for part in parts:
        # "1Mbps:25(2528"
        # means 1Mbps rate, 25 dBm believed transmit power, 25 dBm card-reported transmit power, 28 dBm effective transmit power due to MIMO
        rate, power = part.split(':')
        power, _ = power.split('(')
        ret.append((
            {'rate': rate},
            to_int(base, power),
        ))
    return ret

def to_expires_after(base: str, value: str) -> dict:
    if base not in {"prefix", "address"}:
        raise ValueError("wrong field")
    parts = value.split(", ")
    ret = {base: parts[0]}
    if len(parts) > 1:
        ret.update(to_duration(f"{base}-expires-after", parts[1]))
    return ret

def to_bandwidth(base: str, value: str) -> dict:
    parts = zip(("rx", "tx"), value.split('/', 1))
    ret = {}
    for suffix, value in parts:
        if value == "unlimited":
            value = -1
        value = int(value)
        ret[f"{base}-{suffix}"] = value
    return ret

def to_float(base: str, value: str) -> dict:
    if base not in {
        "sfp-supply-voltage",
    }:
        raise ValueError("wrong field")
    return {base: float(value)}

def to_ethernet_rates(base: str, value: str) -> list:
    if value == "":
        return {}
    parts = value.split(",")
    ret = []
    for part in parts:
        tags = {"link-mode": part}
        ret.append((
            tags,
            {base: True},
        ))
    return ret

def to_str(base: str, value: str) -> dict:
    return {
        base: value,
    }

PARSERS = [
    to_float,
    to_int,
    to_duration,
    to_txrx,
    to_bool,
    to_rate,
    to_expires_after,
]

ParseFunction = Callable[[str, str], dict|list]

@dataclass
class Request(abc.ABC):
    field_types: dict[str, ParseFunction|None] = field(default_factory=dict)
    tag_props: frozenset[str] = field(default_factory=frozenset)

    r: routeros_api.resource.RouterOsResource | None = None
    proplist: set[str] | None = None

    def __init__(self, *, field_types={}):
        self.field_types = field_types
        self.tag_props = frozenset()

    def detect_parsers(self, entry):
        logging.debug("parsing %s", entry)
        prop_parsers = {}
        for k, v in entry.items():
            if k in self.tag_props | {"id"}:
                continue
            if k in self.field_types:
                p = self.field_types[k]
                if not p:
                    continue
                p(k, v)
                prop_parsers[k] = p
                continue
            for p in PARSERS:
                try:
                    p(k, v)
                    logging.debug("parsed %s as %s", k, p.__name__)
                    prop_parsers[k] = p
                    break
                except ValueError:
                    pass
            else:
                logging.info("failed to find parser for %s='%s'", k, v)
        return prop_parsers

    @property
    def proplist_str(self):
        return ",".join(self.proplist)

    def process_entry(self, points: dict[str, MyPoint], entry: dict):
        p = points[entry.get('id')]
        for tag in self.tag_props:
            if value := entry.get(tag):
                p.tag(tag, value)
        for field, parser in self.field_types.items():
            if field not in entry:
                continue
            try:
                parsed = parser(field, entry[field])
                if isinstance(parsed, list):
                    for tags, fields in parsed:
                        print(
                            p.clone_with_tags().tags(tags).fields(fields).to_line_protocol()
                        )
                else:
                    p.fields(parsed)
            except ValueError:
                pass

    @abc.abstractmethod
    def call(self, points: dict[str, MyPoint]):
        pass

    def __call__(self, points: dict[str, MyPoint]):
        for entry in self.call(points):
            self.process_entry(points, entry)

@dataclass
class MonitorRequest(Request):
    def call(self, points: dict[str, MyPoint]):
        if not points:
            # We didn't find any resources
            return []
        return self.r.call('monitor', {'.proplist': self.proplist_str, '.id': ','.join(points.keys()), 'once': ''})

@dataclass
class Resource(Request):
    field_prop_defaults: dict[str, any] = field(default_factory=dict)
    monitor: Request|None = None

    def __init__(self, *, tag_props={}, field_types={}, field_prop_defaults={}, monitor=None):
        super().__init__(field_types=field_types)
        self.tag_props = frozenset(tag_props)
        self.field_prop_defaults = dict(field_prop_defaults)
        self.monitor = monitor

    def prepare(self, api: routeros_api.api.RouterOsApi, name: str):
        logging.debug("fetching %s", name)
        self.r = api.get_resource(name)

        # Find all integer properties once
        field_parsers = dict()
        ids = set()
        try:
            for entry in self.r.get():
                if 'id' in entry:
                    ids.add(entry['id'])
                field_parsers |= self.detect_parsers(entry)
        except routeros_api.exceptions.RouterOsApiCommunicationError as e:
            if e.original_message == b'no such command prefix':
                # This resource doesn't exist.
                return None
            raise
        proplist = set(self.tag_props | set(field_parsers))
        if 'id' in proplist:
            # ".id" in .proplist but "id" in result :(
            proplist.remove('id')
        proplist.add('.id')
        for p in self.tag_props:
            field_parsers.pop(p, None)

        self.field_types = field_parsers
        self.proplist = proplist

        if self.monitor and ids:
            monitor_field_parsers = dict()
            logging.debug('Calling monitor on %s', ids)
            for entry in self.r.call('monitor', {'.id': ','.join(ids), 'once': ''}):
                monitor_field_parsers |= self.monitor.detect_parsers(entry)
            for p in self.tag_props:
                monitor_field_parsers.pop(p, None)
            self.monitor.r = self.r
            self.monitor.field_types = monitor_field_parsers
            self.monitor.proplist = monitor_field_parsers.keys() | {'.id'}
        return self

    def call(self, points: dict[str, MyPoint]):
        return self.r.call('print', {'.proplist': self.proplist_str})

    def __call__(self, points: dict[str, MyPoint]):
        super().__call__(points)
        if self.monitor:
            self.monitor(points)

@dataclass
class FirewallResource(Resource):
    def __init__(self):
        super().__init__(
            field_types={
                "bytes": to_int,
                "packets": to_int,
                "invalid": to_bool,
            },
            tag_props={
                "id",
                "comment",
                "disabled",
                "dynamic",
                "chain",
                "action",
                "log",
            },
        )

    def prepare(self, api: routeros_api.api.RouterOsApi, name: str):
        self.r = api.get_resource(name)
        try:
            self.r.get()
        except routeros_api.exceptions.RouterOsApiCommunicationError as e:
            if e.original_message == b'no such command prefix':
                # This resource doesn't exist.
                return None
            raise
        return self

    def call(self, points: dict[str, MyPoint]):
        # No proplist so we fetch every property
        return self.r.call('print')

    def process_entry(self, points: dict[str, MyPoint], entry: dict):
        p = points[entry.get('id')]
        rule = []
        for key, value in sorted(entry.items()):
            if key in {"id", "comment", "disabled", "dynamic"} | self.field_types.keys():
                continue
            if isinstance(value, str) and ('"' in value or not value):
                value = f'"{value.replace('"', '\\"')}"'
            else:
                value = str(value)
            rule.append(f"{key}={value}")
        p.tag("rule", " ".join(rule))
        super().process_entry(points, entry)

TAGS = {
    "/interface/ethernet/switch/port": Resource(
        tag_props={
            "id",
            "name",
            "switch",
        },
    ),
    "/interface/ethernet": Resource(
        tag_props={
            "id",
            "name",
            "default-name",
            "mac-address",
            "orig-mac-address",
            "switch",
            "disabled",
        },
        field_types={
            "bandwidth": to_bandwidth,
            "loop-protect-status": to_str,
            "poe-out": to_str,
            "sfp-rate-select": to_str,
            "fec-mode": to_str,
            "advertise": None,
            "arp": None,
            "arp-timeout": None,
            "loop-protect": None,
            "loop-protect-send-interval": None,
            "loop-protect-disable-time": None,
            "power-cycle-interval": None,
            "tx-flow-control": None, # Prefer prop from monitor
            "rx-flow-control": None, # Prefer prop from monitor
        },
        monitor=MonitorRequest(
            field_types={
                "status": to_str,
                "auto-negotiation": to_str,
                "sfp-type": to_str,
                "sfp-connector-type": to_str,
                "sfp-vendor-name": to_str,
                "sfp-vendor-part-number": to_str,
                "sfp-vendor-revision": to_str,
                "sfp-vendor-serial": to_str,
                "sfp-manufacturing-date": to_str,
                "eeprom": None,
                "eeprom-checksum": lambda base, value: { f"{base}-good": value == "good" },
                "supported": to_ethernet_rates,
                "sfp-supported": to_ethernet_rates,
                "advertising": to_ethernet_rates,
                "link-partner-advertising": to_ethernet_rates,
            },
        ),
    ),
    "/interface/wireless": Resource(
        tag_props={
            "default-name",
            "name",
            "comment",
            "security-profile",
            "mac-address",
            "radio-name",
            "ssid",
            "interface-type",
            "master-interface",
            "mode",
            "disabled",
            "band",
        },
        field_types={
            "wireless-protocol": to_str,
        },
        monitor=MonitorRequest(
            field_types={
                "channel": to_channel,
                "status": to_str,
                "wireless-protocol": to_str,
                "current-tx-powers": to_current_tx_powers,
            },
        ),
    ),
    "/interface/wireless/registration-table": Resource(
        tag_props={
            "interface",
            "mac-address",
            "last-ip",
            "authentication-type",
            "encryption",
            "group-encryption"
        },
        field_types={
            "tx-rate-set": to_str,
            "signal-strength": to_signal,
            "strength-at-rates": to_strength_at_rates,
        },
    ),
    "/interface/pptp-client": Resource(
        tag_props={
            "name",
            "comment",
            "disabled",
            "connect-to",
            "profile",
            "dial-on-demand",
            "mrru",
            "use-peer-dns",
            "allow",
            "add-default-route",
        },
        field_types={
            "user": None,
            "password": None,
        },
        monitor=MonitorRequest(
            field_types={
                "status": to_str,
                "encoding": to_str,
                "local-address": to_str,
                "remote-address": to_str,
                ".about": None,
            },
        ),
    ),
    "/interface": Resource(
        tag_props={
            "name",
            "default-name",
            "type",
            "mac-address",
            "comment",
            "disabled",
            "slave",
            "mtu",
        },
    ),
    "/ip/dhcp-server/lease": Resource(
        tag_props={
            "blocked",
            "disabled",
            "dynamic",
            "mac-address",
            "client-id",
            "server",
            "address",
            "comment",
            "dhcp-option",
        },
        field_types={
            "status": to_str,
            "active-address": to_str,
            "active-client-id": to_str,
            "active-mac-address": to_str,
            "active-server": to_str,
            "class-id": to_str,
            "host-name": to_str,
        },
    ),
    "/ip/ipsec/active-peers": Resource(
        tag_props={
            "side",
            "responder",
            "local-address",
            "port",
            "remote-address",
        },
        field_types={
            "state": to_str,
            "spii": None,
            "spir": None,
        },
    ),
    "/ip/ipsec/policy": Resource(
        tag_props={
            "id",
            "comment",
            "disabled",
            "dynamic",
            "default",
            #"invalid",
            "template",
            "proposal",
            "peer",
            "group",
            "src-address",
            "dst-address",
            "src-port",
            "dst-port",
            "protocol",
            "ipsec-protocols",
            "action",
            "level",
        },
        field_types={
            "ph2-state": to_str,
            "sa-src-address": to_str,
            "sa-dst-address": to_str,
        },
    ),
    "/ip/ipsec/statistics": Resource(),
    "/ip/address": Resource(
        tag_props={
            "comment",
            "actual-interface",
            "interface",
            "dynamic",
            "disabled",
            "id"
        },
        field_types={
            "address": to_str,
            "network": to_str,
        },
    ),
    "/ipv6/address": Resource(
        tag_props={
            "comment",
            "actual-interface",
            "interface",
            "dynamic",
            "disabled",
            "from-pool",
            "advertise",
            "eui-64",
            "no-dad",
            "link-local",
        },
    ),
    "/ip/dhcp-client": Resource(
        tag_props={
            "comment",
            "interface",
            "request",
            "dynamic",
            "disabled",
            "add-default-route",
            "default-route-distance",
            "dhcp-options",
            "use-peer-dns",
            "use-peer-ntp",
        },
        field_types={
            "status": to_str,
            "gateway": to_str,
            "dhcp-server": to_str,
            "primary-dns": to_str,
            "secondary-dns": to_str,
            "script": None,
        },
    ),
    "/ipv6/dhcp-client": Resource(
        tag_props={
            "comment",
            "interface",
            "disabled",
            "request",
            "dhcp-options",
            "pool-name",
            "prefix-hint",
            "add-default-route",
            "rapid-commit",
            "pool-prefix-length",
        },
        field_types={
            "address": to_expires_after,
            "status": to_str,
            "duid": to_str,
            "dhcp-server-v6": to_str,
        },
    ),
    # "/ip/route": {
    #     "tag_props": {
    #         "id",
    #         "comment",
    #         "dynamic",
    #         "dhcp",
    #         "disabled",
    #         "routing-table",
    #         "dst-address",
    #         "gateway",
    #         "distance",
    #         "static",
    #         "scope",
    #         "target-scope",
    #         "vrf-interface",
    #         "check-gateway",
    #         "suppress-hw-offload",
    #     },
    # },
    "/routing/route": Resource(
        tag_props={
            "id",
            "comment",
            "afi",
            "belongs-to",
            "vrf-interface",
            "routing-table",
            "dst-address",
            "gateway",
            "distance",
            "scope",
            "target-scope",
            "disabled",
            "check-gateway",
            "bgp",
            "blackhole",
            "connect",
            "ecmp",
            "ospf",
            "rip",
            "static",
            "vpn",
        },
        field_types={
            "contribution": to_str,
            "nexthop-id": to_str,
            "immediate-gw": to_str,
            "local-address": to_str,
            "debug.fwp-ptr": None,
        },
        field_prop_defaults={
            "active": False,
        },
    ),
    "/ip/pool": Resource(
        tag_props={
            "name",
            "ranges",
        },
    ),
    "/ip/firewall/filter": FirewallResource(),
    "/ip/firewall/nat": FirewallResource(),
    "/ip/firewall/raw": FirewallResource(),
    "/ipv6/firewall/filter": FirewallResource(),
    "/ipv6/firewall/nat": FirewallResource(),
    "/ipv6/firewall/raw": FirewallResource(),
}

async def main():
    parser = argparse.ArgumentParser(description='Extract edgeos metrics.')
    parser.add_argument('--server', metavar='IP', required=True,
                        help='edgeos server to scrape')
    parser.add_argument('--user', metavar='USER', required=True,
                        help='username')
    parser.add_argument('--password', metavar='PASSWORD', required=True,
                        help='password')
    parser.add_argument('--plaintext-login', action='store_true', default=False)
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--resource-type', '-r', metavar='PATH', default=None)

    args = parser.parse_args()

    logging.basicConfig(level=logging.NOTSET if args.verbose else logging.INFO)

    conn = routeros_api.RouterOsApiPool(
        args.server,
        username=args.user,
        password=args.password,
        plaintext_login=args.plaintext_login,
    )
    api = conn.get_api()

    tags = TAGS

    if t := args.resource_type:
        if t in tags:
            tags = {t: tags[t]}
        else:
            tags = {t: Resource()}

    resources = {}

    for name, config in tags.items():
        logging.debug("fetching %s", name)
        resource = config.prepare(api, name)
        if not resource:
            continue
        resources[name] = resource

    logging.debug("identified resources: %s", resources)

    # Retrieve hostname
    hostname = api.get_resource("/system/identity").get()[0]["name"]

    sys.stdout = io.TextIOWrapper(io.BufferedWriter(sys.stdout.buffer.raw, 1*1024*1024))

    for line in sys.stdin:
        t = time.time_ns()
        for measurement, m in resources.items():
            logging.debug("listing %s: %s", measurement, m)
            def point():
                return MyPoint(measurement) \
                    .time(t) \
                    .tag("agent_host", args.server) \
                    .tag("hostname", hostname) \
                    .fields(m.field_prop_defaults)
            points = defaultdict(point)
            m(points)
            for p in points.values():
                try:
                    l = p.to_line_protocol()
                    if l:
                        print(l)
                except ValueError:
                    logging.exception("failed to print %s", p._fields)
                    raise
        sys.stdout.flush()


if __name__ == "__main__":
    asyncio.run(main())
