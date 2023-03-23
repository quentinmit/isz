#!/usr/bin/env nix-shell
#!nix-shell -i bash -p common-updater-scripts nodePackages.node2nix curl jq gnused nix coreutils

set -exuo pipefail

pushd .
cd "$(dirname "${BASH_SOURCE[0]}")"/../../..

latestVersion="$(curl -s "https://api.github.com/repos/zwave-js/zwave-js-ui/releases?per_page=1" | jq -r ".[0].tag_name[1:]")"
currentVersion=$(nix eval --raw '.#pkgs.zwave-js-ui.version')

if [[ "$currentVersion" == "$latestVersion" ]]; then
    echo "zwave-js-ui is up-to-date: $currentVersion"
    #exit 0
fi

#update-source-version pkgs.zwave-js-ui "$latestVersion"

store_src="$(nix-build . -A pkgs.zwave-js-ui.src --no-out-link)"

popd
cd "$(dirname "${BASH_SOURCE[0]}")"

node2nix \
    --node-env ./node-env.nix \
    --input "$store_src"/package.json \
    --output ./node-packages.nix \
    --composition ./node-composition.nix
#    --nodejs-12 \
#    --development \
#    --lock "$store_src"/package-lock.json \
