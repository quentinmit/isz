#!/usr/bin/env python3

import argparse
from collections import defaultdict
import logging
import re
from functools import cached_property
from frozendict import frozendict
from netaddr import IPAddress, IPNetwork
import routeros_api
import socket
import sys
import netrc
import toml
from typing import Container, Optional, TypedDict
import dns.zone


class Input(TypedDict):
    path: str
    skip_records: Optional[Container[str]]

Record = TypedDict('Record', {
    '_resource': str,
    'name': str,
    'regexp': str,
    'type': str,
    'address': str,
    'ttl': str,
    'comment': str,
    'forward-to': str,
}, total=False)


def parse_file(input: Input) -> dict[str, Record]:
    """
    Parse a file of DNS data. See `hosts.txt.sample` for examples

    :param: path Path to DNS data file
    :return: A dictionary of DNS data in the format:
             {
                 "<hostname>": {
                     "name": "<hostname>",
                     "type": "A",
                     "address": "IP addr",
                     "ttl": "30m",
                     "comment": "Comment",
                 }
             }
    """
    zone = dns.zone.from_file(input["path"], origin='.', relativize=False, check_origin=False)

    def map_record(name, rec) -> Container[Record]:
        objects = []
        for rd in rec.rdatasets:
            out = {
                "_resource": "/ip/dns/static",
                "type": rd.rdtype.name,
                "ttl": str(rd.ttl//60) + "m",
            }
            if rd[0].rdcomment:
                out["comment"] = rd[0].rdcomment.strip()
            name = str(name).rstrip('.')
            if "*" in name:
                out["regexp"] = name.replace(".", r"\.").replace("*", ".*") + "$"
            else:
                out["name"] = name

            if rd[0].rdcomment and rd[0].rdcomment.strip().startswith("FWD"):
                out["type"] = "FWD"
                out["forward-to"] = rd[0].address
            elif rd.rdtype == dns.rdatatype.A:
                out["address"] = rd[0].address
            elif rd.rdtype == dns.rdatatype.CNAME:
                out["cname"] = str(rd[0].target)[:-1]
            elif rd.rdtype == dns.rdatatype.SRV:
                out["srv-priority"] = str(rd[0].priority)
                out["srv-weight"] = str(rd[0].weight)
                out["srv-port"] = str(rd[0].port)
                out["srv-target"] = str(rd[0].target)[:-1]
            elif rd.rdtype == dns.rdatatype.EUI48:
                out = {
                    "_resource": "/ip/dhcp-server/lease",
                    "mac-address": ":".join("%02X" % x for x in rd[0].eui),
                    "comment": out.get("comment", out["name"]),
                }
                for rd in rec.rdatasets:
                    if rd.rdtype == dns.rdatatype.A:
                        out["address"] = rd[0].address
            else:
                logging.warning("Ignoring unknown record of type %s", rd.rdtype)
            # TODO: Support more record types

            objects.append(out)
        return objects
    return {
        # Strip trailing . from names.
        str(name)[:-1]: map_record(name, rec)
        for name, rec in zone.items()
        if str(name)[:-1] not in input.get("skip_records", set())
    }


def get_entry_name(entry):
    if "name" in entry:
        return entry["name"]
    if "regexp" in entry:
        return entry["regexp"].replace('.*', '*').replace(r"\.", ".").rstrip("$")


def mikrotik_to_record(resource_type: str, entry: dict) -> Record:
    out = dict(entry)
    out["_resource"] = resource_type
    del out["id"]
    del out["dynamic"]
    del out["disabled"]
    if resource_type == '/ip/dns/static':
        if 'type' not in out:
            out['type'] = 'A'
    elif resource_type == '/ip/dhcp-server/lease':
        # Remove dynamic keys
        for key in 'status expires-after last-seen active-server active-address active-mac-address active-client-id host-name radius blocked'.split():
            out.pop(key, None)
        for key in set(out.keys()):
            if not out[key]:
                del out[key]

    return frozendict(out)


def netrc_lookup(server):
    if "username" in server and "password" in server:
        return server["username"], server["password"]
    try:
        n = netrc.netrc()
        for key in (server.get("host"), server.get("name"), "default"):
            if not key:
                continue
            if key in n.hosts:
                login, _, password = n.hosts[key] or [None, None, None]
                return server.get("username") or login, server.get("password") or password
    except FileNotFoundError:
        pass
    return server["username"], server["password"]

class Server:
    def __init__(self, server):
        username, password = netrc_lookup(server)
        self.conf = server
        self.conn = routeros_api.RouterOsApiPool(
            server["host"],
            username=username,
            password=password,
            plaintext_login=server["plaintext_login"],
        )
        self.api = self.conn.get_api()

    @cached_property
    def dhcp_server_by_network(self):
        networks = {r['interface']: IPNetwork(r['address']).cidr for r in self.api.get_resource('/ip/address').get()}
        out = {}
        for dhcp_server in self.api.get_resource('/ip/dhcp-server').get():
            interface = dhcp_server['interface']
            if interface in networks:
                out[networks[interface]] = dhcp_server['name']
        return out

    def get_dhcp_server_for_address(self, address):
        address = IPAddress(address)
        for network, name in self.dhcp_server_by_network.items():
            if address in network:
                return name

    def get_records_by_type(self, hosts: dict) -> dict:
        server_records = defaultdict(set)
        for records in hosts.values():
            for r in records:
                r = dict(r)
                if r.get('forward-to') == self.conf['host']:
                    continue
                if r['_resource'] == '/ip/dhcp-server/lease':
                    if 'address' in r:
                        r['server'] = self.get_dhcp_server_for_address(r['address'])
                        if not r['server']:
                            continue
                server_records[r['_resource']].add(frozendict(r))
        return server_records


def dns_update(hosts: dict, config: dict, dry_run: bool = True):
    # Number of entries added or removed across all servers
    count_operations = 0

    for server in config["server"]:
        # For each Mikrotik server
        logging.info("Processing Mikrotik server %s", server['host'])

        s = Server(server)
        api = s.api

        logging.info("Found DHCP networks: %s", s.dhcp_server_by_network)

        server_records = s.get_records_by_type(hosts)

        for resource_type, resource_records in server_records.items():
            mikrotik_resource = api.get_resource(resource_type)

            records_to_add = set(resource_records)

            # Go through existing records and delete anything that's changing or no longer in hosts file
            for entry in mikrotik_resource.get():
                if entry.get('dynamic') == 'true':
                    continue
                record = mikrotik_to_record(resource_type, entry)
                if record in resource_records:
                    # Nothing changed. Do not insert this host again.
                    records_to_add.remove(record)
                else:
                    # Clear out old records that no longer appear in the hosts file
                    count_operations += 1
                    if not dry_run:
                        mikrotik_resource.remove(id=entry["id"])
                    logging.info(
                        " - deleting existing entry for %s - %s",
                        entry.get('name', str(entry)), record,#entry.get('address'),
                    )

            # Add all of our entries
            for entry in sorted(records_to_add, key=lambda r: r.get('name', r.get('mac-address'))):
                kwargs = dict(entry)
                del kwargs['_resource']
                if server.get('old_dns'):
                    if kwargs['type'] != 'A':
                        continue
                    del kwargs['type']
                logging.info(
                    " - inserting entry for %s - %s",
                    entry.get('name', str(entry)), kwargs,
                )
                count_operations += 1
                if not dry_run:
                    try:
                        mikrotik_resource.add(**kwargs)
                    except routeros_api.exceptions.RouterOsApiCommunicationError as e:
                        if e.original_message == b'unknown parameter':
                            logging.warning("skipping: %s", e.original_message)
                        else:
                            raise

    return count_operations

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("hosts_file", nargs="*", help="Path to hosts file", type=str)
    parser.add_argument(
        "--config", help="Configuration file path", type=str, default="config.toml"
    )
    parser.add_argument(
        "--parse-only",
        help="Only parse the hosts file and dump output",
        action="store_true",
    )
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--dry-run", "-n", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    with open(args.config, "r") as config_file:
        config_data = toml.load(config_file)

    data = {}

    inputs = config_data.get("input", [])
    inputs.extend([{"path": p} for p in args.hosts_file])

    if not inputs:
        raise ValueError("no input files specified")

    for f in inputs:
        try:
            data.update(parse_file(f))
        except ValueError as err:
            print(str(err))
            return 1

    if args.parse_only:
        # Parse the file and dump DNS data to stdout
        import pprint

        pp = pprint.PrettyPrinter()
        pp.pprint(data)
        return 0

    num_updates = dns_update(data, config_data, dry_run=args.dry_run)
    if num_updates == 0:
        print("No changes made")
        return 2
    return 0

if __name__ == "__main__":
    sys.exit(main())
