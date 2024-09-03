#!/usr/bin/env python3

from lxml import html
import sys
import requests
import json

def main():
    response = requests.get("https://lg.he.net", stream=True)
    response.raw.decode_content = True
    tree = html.parse(
        response.raw,
        parser=html.HTMLParser(encoding='utf-8')
    )

    out = []
    for e in tree.xpath('//select[@name="routers[]"]//option[@value]'):
        x = {
            'host': e.get('value'),
            'country': e.get('data-iso3166').upper(),
            'city': e.get('data-location')[:-4],
            'datacenter': e.text.strip(),
        }
        if x['country'] == 'US':
            x['state'] = x['city'][-2:]
            x['city'] = x['city'][:-4]
        if exchanges := e.get('data-exchanges'):
            x['exchanges'] = exchanges.split(', ')
        out.append(x)
    json.dump(
        {
            'he_lg_ping_targets': out,
        },
        fp=sys.stdout,
        sort_keys=False,
        indent=2,
    )
# $ pbpaste | yq eval '... style="" | (.[] | select(.exchanges) | .exchanges) style="flow" | (.[].country | select(. == "NO")) style="double"' - | pbcopy

if __name__ == "__main__":
    main()
