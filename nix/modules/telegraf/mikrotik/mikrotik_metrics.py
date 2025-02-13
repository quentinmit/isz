#!/usr/bin/python3
from influxdb_client import Point
import asyncio
import argparse
import functools
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
    if not base.endswith("-rate"):
        raise ValueError("not rate")
    d = {
        base+"-name": value,
    }
    parts = value.split("-", 1)
    num = parts[0]
    if num.endswith("Mbps"):
        d[base] = int(float(num[:-4])*1e6)
    return d

def to_channel(base: str, value: str) -> dict:
    if not base == 'channel':
        raise ValueError("wrong field")
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
    if base != "signal-strength":
        raise ValueError("wrong field")
    rssi, rate = value.split('@', 1)
    return to_int(base, rssi) | to_rate(base + '-rate', rate)

def to_strength_at_rates(base: str, value: str) -> list:
    if base != "strength-at-rates":
        raise ValueError("wrong field")
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
    if base != "current-tx-powers":
        raise ValueError("wrong field")
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

def to_expires_after(base: str, value: str) -> list:
    if base not in {"prefix", "address"}:
        raise ValueError("wrong field")
    parts = value.split(", ")
    ret = {base: parts[0]}
    if len(parts) > 1:
        ret.update(to_duration(f"{base}-expires-after", parts[1]))
    return ret

STRING_FIELDS = {
    "tx-rate-set",
    "active-address",
    "active-mac-address",
    "active-client-id",
    "active-server",
    "state",
    "status",
    "ph2-state",
    "host-name",
    "wireless-protocol",
    "local-address",
    "remote-address",
    "src-address",
    "dst-address",
    "sa-src-address",
    "sa-dst-address",
    "encoding",
    "address",
    "network",
    "gateway",
    "dhcp-server",
    "primary-dns",
    "secondary-dns",
    "duid",
    "dhcp-server-v6",
}

def to_str(base: str, value: str) -> dict:
    if base not in STRING_FIELDS:
        raise ValueError("unknown field")
    return {
        base: value,
    }
PARSERS = [
    to_int,
    to_duration,
    to_txrx,
    to_bool,
    to_rate,
    to_signal,
    to_channel,
    to_strength_at_rates,
    to_current_tx_powers,
    to_expires_after,
    to_str,
]

TAGS = {
    "/interface/ethernet/switch/port": {
        "tag_props": {
            "id",
            "name",
            "switch",
        },
    },
    "/interface/wireless": {
        "tag_props": {
            "default-name",
            "name",
            "mac-address",
            "radio-name",
            "ssid",
            "interface-type",
            "master-interface",
            "mode",
            "disabled",
            "band",
        },
        "monitor": True,
    },
    "/interface/wireless/registration-table": {
        "tag_props": {
            "interface",
            "mac-address",
            "last-ip",
            "authentication-type",
            "encryption",
            "group-encryption"
        },
    },
    "/interface/pptp-client": {
        "tag_props": {
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
        "skip_props": {
            "user",
            "password",
        },
        "monitor": True,
    },
    "/interface": {
        "tag_props": {
            "name",
            "default-name",
            "type",
            "mac-address",
            "comment",
            "disabled",
            "slave",
            "mtu",
        },
    },
    "/ip/dhcp-server/lease": {
        "tag_props": {
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
    },
    "/ip/ipsec/active-peers": {
        "tag_props": {
            "side",
            "responder",
            "local-address",
            "port",
            "remote-address",
        },
        "skip_props": {
            "spii",
            "spir",
        },
    },
    "/ip/ipsec/policy": {
        "tag_props": {
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
    },
    "/ip/ipsec/statistics": {},
    "/ip/address": {
        "tag_props": {
            "comment",
            "actual-interface",
            "interface",
            "dynamic",
            "disabled",
        },
    },
    "/ipv6/address": {
        "tag_props": {
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
    },
    "/ip/dhcp-client": {
        "tag_props": {
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
        "skip_props": {
            "script",
        },
    },
    "/ipv6/dhcp-client": {
        "tag_props": {
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
    },
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
            tags = {t: {'tag_props': set()}}

    resources = {}

    for name, props in tags.items():
        r = api.get_resource(name)

        tag_props = props.get('tag_props', set())
        skip_props = props.get('skip_props', set())
        # Find all integer properties once
        field_props = set()
        def parse_entry(entry):
            logging.debug("parsing %s", entry)
            single_props = set()
            for k, v in entry.items():
                if k in tag_props | {"id"}:
                    continue
                if k in skip_props:
                    continue
                for p in PARSERS:
                    try:
                        p(k, v)
                        single_props.add(k)
                        break
                    except ValueError:
                        pass
                else:
                    logging.debug("failed to find parser for %s='%s'", k, v)
            return single_props
        ids = set()
        try:
            for entry in r.get():
                if 'id' in entry:
                    ids.add(entry['id'])
                field_props |= parse_entry(entry)
        except routeros_api.exceptions.RouterOsApiCommunicationError as e:
            if e.original_message == b'no such command prefix':
                # This resource doesn't exist.
                continue
            raise
        proplist = tag_props | field_props
        if 'id' in proplist:
            # ".id" in .proplist but "id" in result :(
            proplist.remove('id')
        proplist.add('.id')
        proplist = ','.join(list(proplist))
        field_props -= tag_props
        resources[name] = {
            'r': r,
            'tag_props': tag_props,
            'field_props': field_props,
            'proplist': proplist,
        }
        if props.get('monitor') and ids:
            monitor_field_props = set()
            logging.debug('Calling monitor on %s', ids)
            for entry in r.call('monitor', {'.id': ','.join(ids), 'once': ''}):
                monitor_field_props |= parse_entry(entry)
            resources[name]['monitor'] = {
                'field_props': monitor_field_props,
                'proplist': ','.join(monitor_field_props | {'.id'}),
            }

    logging.debug("identified resources: %s", resources)

    # Retrieve hostname
    hostname = api.get_resource("/system/identity").get()[0]["name"]

    for line in sys.stdin:
        t = time.time_ns()
        def point(measurement):
            return MyPoint(measurement) \
                .time(t) \
                .tag("agent_host", args.server) \
                .tag("hostname", hostname)
        for measurement, m in resources.items():
            logging.debug("listing %s: %s", measurement, m)
            points = dict()
            def process_field_props(p, entry, field_props):
                for field in field_props:
                    if field not in entry:
                        continue
                    for parser in PARSERS:
                        try:
                            parsed = parser(field, entry[field])
                            if isinstance(parsed, list):
                                for tags, fields in parsed:
                                    print(
                                        p.clone_with_tags().tags(tags).fields(fields).to_line_protocol()
                                    )
                                break
                            p.fields(parsed)
                            break
                        except ValueError:
                            pass
            for entry in m['r'].call('print', {'.proplist': m['proplist']}):
                p = point(measurement)
                for tag in m['tag_props']:
                    if value := entry.get(tag):
                        p.tag(tag, value)
                process_field_props(p, entry, m['field_props'])
                points[entry.get('id')] = p
            if 'monitor' in m:
                for entry in m['r'].call('monitor', {'.proplist': m['monitor']['proplist'], '.id': ','.join(points.keys()), 'once': ''}):
                    p = points[entry['id']]
                    process_field_props(p, entry, m['monitor']['field_props'])
            for p in points.values():
                try:
                    l = p.to_line_protocol()
                    if l:
                        print(l)
                except ValueError:
                    logging.exception("failed to print %s", p._fields)
                    raise


if __name__ == "__main__":
    asyncio.run(main())
