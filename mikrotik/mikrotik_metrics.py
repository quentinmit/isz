#!/usr/bin/python3
from influxdb_client import Point
import asyncio
import argparse
import functools
import logging
import sys
import time
import routeros_api


class MyPoint(Point):
    def fields(self, fields: dict):
        for name, value in fields.items():
            self.field(name, value)
        return self

TAGS = {
    "/interface/ethernet/switch/port": {
        "name",
    },
    "/interface/wireless/registration-table": {
        "interface",
        "mac-address",
        "last-ip",
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

    for name, tag_props in TAGS.items():
        r = api.get_resource(name)

        # Find all integer properties once
        field_props = set()
        for entry in r.get():
            single_props = set()
            for k, v in entry.items():
                try:
                    int(v)
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
                    try:
                        p.field(field, int(entry.get(field, "")))
                    except ValueError:
                        pass
                print(p.to_line_protocol())


if __name__ == "__main__":
    asyncio.run(main())
