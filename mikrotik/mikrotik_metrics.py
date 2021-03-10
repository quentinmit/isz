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


def collect(server: str, get: dict, metrics: dict):
    t = time.time_ns()
    def point(measurement):
        return MyPoint(measurement) \
            .time(t) \
            .tag("agent_host", server) \
            .tag("hostname", get["GET"]["system"]["host-name"])
        # TODO: Add tag for server-reported hostname
    try:
        for key, data in metrics.items():
            if key == 'system-stats':
                # {'cpu': '2', 'uptime': '8909260', 'mem': '5', 'temps': {'Board (CPU)': '11 C', 'CPU': '25 C', 'Board (PHY)': '17 C', 'PHY': '32 C'}, 'power': {'System input voltage      ': ' 51.05 V', 'Terminal block current    ': ' 0.00 mA', 'POE-IN ETH0 current       ': ' 573.79 mA', 'POE-IN ETH8 current       ': ' 0.00 mA', 'System power consumption  ': ' 29.29 W'}
                out(point(key).fields({k: int(v) for k,v in data.items() if k in ('cpu', 'mem', 'uptime')}).to_line_protocol())
                for sensor_type in ("temps", "power"):
                    sensor_data = data.get(sensor_type, {})
                    for sensor, value in sensor_data.items():
                        value, unit = value.strip().split(maxsplit=1)
                        out(point(key).tag('unit', unit).tag('sensor', sensor.strip()).field(sensor_type, float(value)).to_line_protocol())
            elif key == 'interfaces':
                # {'interfaces': {'br0.2583': {'up': 'true', 'l1up': 'true', 'mac': '80:2a:a8:9e:98:6d', 'mtu': '1500', 'addresses': ['172.25.83.27/24'], 'stats': {'rx_packets': '25914989', 'tx_packets': '7832498', 'rx_bytes': '1565446649', 'tx_bytes': '997773696', 'rx_errors': '0', 'tx_errors': '0', 'rx_dropped': '0', 'tx_dropped': '0', 'multicast': '696824', 'rx_bps': '925', 'tx_bps': '10026'}}}}
                for if_name, if_data in data.items():
                    p = point(key).tag("if-name", if_name).tag('mtu', int(if_data['mtu'])).field('up', if_data['up'] == 'true')
                    if 'mac' in if_data:
                        p.tag('mac', if_data['mac'])
                    out(p.fields({k: int(v) for k,v in if_data['stats'].items()}).to_line_protocol())
            elif key == 'num-routes':
                out(point(key).fields({k: int(v) for k,v in data.items()}).to_line_protocol())
            else:
                logging.warning("unknown stat %s: %r", key, data)
    except:
        logging.exception('failed to translate point')

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

    port = api.get_resource("/interface/ethernet/switch/port")

    # Find all integer properties once
    field_props = set()
    for entry in port.get():
        single_props = set()
        for k, v in entry.items():
            try:
                int(v)
                single_props.add(k)
            except ValueError:
                pass
        field_props |= single_props
    tag_props = {"name"}
    proplist = '.id,'+','.join(list(tag_props) + list(field_props))
    tag_props.add('id') # ".id" in .proplist but "id" in result :(

    # Retrieve hostname
    hostname = api.get_resource("/system/identity").get()[0]["name"]

    for line in sys.stdin:
        t = time.time_ns()
        def point(measurement):
            return MyPoint(measurement) \
                .time(t) \
                .tag("agent_host", args.server) \
                .tag("hostname", hostname)
        for entry in port.call('print', {'.proplist': proplist}):
            p = point("/interface/ethernet/switch/port")
            for tag in tag_props:
                if value := entry.get(tag):
                    p.tag(tag, value)
            for field in field_props:
                try:
                    p.field(field, int(entry.get(field, "")))
                except ValueError:
                    pass
            print(p.to_line_protocol())


if __name__ == "__main__":
    asyncio.run(main())
