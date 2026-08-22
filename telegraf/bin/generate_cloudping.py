#!/usr/bin/env python3

import csv
from lxml import html
import sys
import requests
import urllib.parse
import json

locations = """
location,city,state,country
Amsterdam,Amsterdam,,NL
"Ashburn, Virginia",Ashburn,VA,US
Atlanta,Atlanta,GA,US
Bangalore,Bangalore,,IN
Beauharnois,Beauharnois,QC,CA
Beijing,Beijing,,CN
Belgium,,,BE
Berlin,Berlin,,DE
California,,CA,US
Canada Central,Varennes,QC,CA
Canada West,Calgary,AB,CA
Cape Town,Cape Town,,ZA
Chicago,Chicago,IL,US
Columbus,Columbus,OH,US
Dallas,Dallas,TX,US
Delhi NCR,Delhi,,IN
Delhi,,IN
Doha,Doha,,QA
"Falkenstein, Germany",Falkenstein,,DE
Finland,,,FI
France,,,FR
Frankfurt,Frankfurt,,DE
Fremont (San Francisco),Fremont,CA,US
Gravelines,Gravelines,,FR
"Hillsboro, Oregon",Hillsboro,OR,US
Hong Kong,Hong Kong,,HK
Honolulu,Honolulu,HI,US
Hyderabad,Hyderabad,,IN
Iowa,,IA,US
Ireland,,,IE
Jakarta,Jakarta,,ID
Johannesburg,Johannesburg,,ZA
Las Vegas,Las Vegas,NV,US
London,London,,UK
Los Angeles,Los Angeles,CA,US
Madrid,Madrid,,ES
Manchester,Manchester,,UK
Melbourne,Melbourne,,AU
Mexico City,Mexico City,,MX
Mexico,,,MX
Miami,Miami,FL,US
Milan,Milan,,IT
Montréal,Montréal,QC,UK
Mumbai,Mumbai,,IN
Netherlands,,,NL
New Jersey,,NJ,US
New York,New York,NY,US
Newark (New York),Newark,NJ,US
Ningxia,Ningxia,,CN
North Virginia,Ashburn,VA,US
"Nuremberg, Germany",Nuremberg,,DE
Ohio,,OH,US
Oregon,,OR,US
Osaka,Osaka,,JP
Palo Alto,Palo Alto,CA,US
Paris,Paris,,FR
Poland,,,PL
Roubaix,Roubaix,,FR
Salt Lake City,Salt Lake City,UT,US
San Francisco,San Francisco,CA,US
Santiago,Santiago,,CL
Seattle,Seattle,WA,US
Seoul,Seoul,,KR
Silicon Valley,San Jose,CA,US
Singapore,Singapore,,SG
South Carolina,,SC,US
Spain,,,ES
Stockholm,Stockholm,,SE
Strasbourg,Strasbourg,,FR
Sydney,Sydney,,AU
São Paulo,São Paulo,,BR
Taipei,Taipei,,TW
Taiwan,,,TW
Tel Aviv,Tel Aviv,,IL
Tokyo,Tokyo,,JP
Toronto,Toronto,ON,CA
Turin,Turin,,IT
Virginia,,VA,US
Warsaw,Warsaw,,PL
Washington DC,Washington,DC,US
Zurich,Zurich,,CH
il-central-1,,,IL
me-central-1,,,AE
me-central2,Dammam,,SA
me-south-1,,,BH
me-west1,Tel Aviv,,IL
us-gov-east-1,Columbus,OH,US
us-gov-west-1,,OR,US
global,,,
"""

locations = {row["location"]: row for row in csv.DictReader(locations.strip().splitlines())}

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
                x['location'] = parts.pop()
                if parts:
                    x['location'] = parts.pop()
                #if ',' in x['country']:
                #    x['city'], x['country'] = x['country'].split(', ')

            case 'Vultr':
                x['location'] = parts.pop(0)
        x['ipv4'] = service_name in (
            'Amazon Web Services',
            'DigitalOcean',
            # Anycast: 'Google Cloud Platform',
            'Hetzner',
            'IBM Cloud',
            'Linode',
            'OVH Cloud',
            'Scaleway',
            'Vultr',
        )
        x['ipv6'] = service_name in (
            # Anycast: 'Google Cloud Platform',
            'Hetzner',
            'Linode',
            'OVH Cloud',
            'Scaleway',
        )
        parts = None
        if 'location' in x:
            parts = locations.get(x['location'])
        if not parts and 'datacenter' in x:
            parts = locations.get(x['datacenter'])
        if not parts:
            raise ValueError(f"Don't know where to find {x}")
        if 'location' in x:
            del x['location']
        x |= {k: v for k,v in parts.items() if k != "location" and v}
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
