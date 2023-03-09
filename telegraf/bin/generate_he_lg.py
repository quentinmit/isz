#!/usr/bin/env python3

from lxml import html
import sys
import requests
import yaml

class FlowList(yaml.YAMLObject, list):
    yaml_tag = 'flowlist'
    yaml_flow_style = True

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_sequence('tag:yaml.org,2002:seq', data, flow_style=True)

def main():
    response = requests.get("https://lg.he.net", stream=True)
    response.raw.decode_content = True
    tree = html.parse(
        response.raw,
        parser=html.HTMLParser(encoding='utf-8')
    )

    out = []
    for e in tree.xpath('//li[./input[@name="routers[]"]]'):
        x = {
            'host': e.find('input').get('value'),
            'country': e.find('./label/span/img').get('alt'),
            'city': e.find('./label/span').text[:-5],
            'datacenter': e.find('./label').text.strip(),
        }
        if x['country'] == 'US':
            x['state'] = x['city'][-2:]
            x['city'] = x['city'][:-4]
        t = e.find('./label').get('title')
        if ' - ' in t:
            x['exchanges'] = FlowList(t.split(' - ', 1)[1].split(', '))
        out.append(x)
    yaml.dump(
        {
            'he_lg_ping_targets': out,
        },
        stream=sys.stdout,
        sort_keys=False, allow_unicode=True,
    )
# $ pbpaste | yq eval '... style="" | (.[] | select(.exchanges) | .exchanges) style="flow" | (.[].country | select(. == "NO")) style="double"' - | pbcopy

if __name__ == "__main__":
    main()
