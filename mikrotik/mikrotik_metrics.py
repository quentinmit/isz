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
    def fields(self, fields: dict):
        for name, value in fields.items():
            self.field(name, value)
        return self

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
    num, name = value.split("-", 1)
    if not num.endswith("Mbps"):
        raise ValueError("not Mbps")
    num = int(float(num[:-4])*1e6)
    return {
        base: num,
        base+"-name": name,
    }

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

PARSERS = [
    to_int,
    to_duration,
    to_txrx,
    to_bool,
    to_rate,
]

TAGS = {
    "/interface/ethernet/switch/port": {
        "tag_props": {
            "name",
            "switch",
        },
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
    parser.add_argument('subscriptions', metavar='STAT', nargs='*',
                        default="interfaces system-stats num-routes config-change".split(),
                        # All: default="export discover pon-stats interfaces system-stats num-routes config-change users".split(),
                        help='list of stats to collect')

    args = parser.parse_args()

    logging.basicConfig(level=logging.NOTSET if args.verbose else logging.INFO)

    conn = routeros_api.RouterOsApiPool(
        args.server,
        username=args.user,
        password=args.password,
        plaintext_login=args.plaintext_login,
    )
    api = conn.get_api()

    resources = {}

    for name, props in TAGS.items():
        r = api.get_resource(name)

        tag_props = props['tag_props']
        # Find all integer properties once
        field_props = set()
        for entry in r.get():
            single_props = set()
            for k, v in entry.items():
                for p in PARSERS:
                    try:
                        p(k, v)
                        single_props.add(k)
                    except ValueError:
                        pass
            field_props |= single_props
        proplist = '.id,'+','.join(list(tag_props) + list(field_props))
        tag_props.add('id') # ".id" in .proplist but "id" in result :(
        field_props -= tag_props
        resources[name] = {
            'r': r,
            'tag_props': tag_props,
            'field_props': field_props,
            'proplist': proplist,
        }

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
            for entry in m['r'].call('print', {'.proplist': m['proplist']}):
                p = point(measurement)
                for tag in m['tag_props']:
                    if value := entry.get(tag):
                        p.tag(tag, value)
                for field in m['field_props']:
                    for parser in PARSERS:
                        try:
                            p.fields(parser(field, entry.get(field, "")))
                            break
                        except ValueError:
                            pass
                print(p.to_line_protocol())


if __name__ == "__main__":
    asyncio.run(main())
