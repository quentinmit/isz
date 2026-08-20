#!/usr/bin/env python3

from lxml import html
import sys
import requests
import urllib.parse
import json

def main():
    response = requests.get("https://www.cloudping.info/", stream=True)
    response.raw.decode_content = True
    tree = html.parse(
        response.raw,
        parser=html.HTMLParser(encoding='utf-8')
    )

    out = []
    service_name = None
    for e in tree.xpath('//tr'):
        if (sn := e.find('./td[@class="service-name"]/a')) is not None:
            service_name = sn.text
            continue
        url = e.find('./td[@class="latency"]')
        if url is None:
            continue
        name = e.find('./td[1]').text.strip()
        url = url.get('pingurl')
        url = urllib.parse.urlsplit(url)
        host = url.hostname
        parts = [x.strip() for x in name.rstrip(')').split('(')]
        #print(service_name, name, host)
        x = {
            'host': url.hostname,
            'service': service_name,
        }
        match service_name:
            case 'Amazon Web Services' | 'CoreWeave' | 'DigitalOcean' | 'Google Cloud Platform' | 'IBM Cloud' | 'Scaleway':
                x['datacenter'] = parts[0]
                if len(parts) > 1 and len(parts[1]) < 20:
                    x['location'] = parts[1]
            case 'Hetzner' | 'Linode':
                x['location'] = name
            case 'OVH Cloud':
                x['country'] = parts.pop()
                if parts:
                    x['city'] = parts.pop()
                if ',' in x['country']:
                    x['city'], x['country'] = x['country'].split(', ')
            case 'Vultr':
                x['location'] = parts.pop(0)
        x['ipv4'] = service_name in (
            'Amazon Web Services',
            'DigitalOcean',
            'Google Cloud Platform',
            'Hetzner',
            'IBM Cloud',
            'Linode',
            'OVH Cloud',
            'Scaleway',
            'Vultr',
        )
        x['ipv6'] = service_name in (
            'Google Cloud Platform',
            'Hetzner',
            'Linode',
            'OVH Cloud',
            'Scaleway',
        )
        out.append(x)
    json.dump(
        {
            'cloudping_targets': out,
        },
        fp=sys.stdout,
        sort_keys=False,
        indent=2,
    )

if __name__ == "__main__":
    main()
