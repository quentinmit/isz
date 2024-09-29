{ stdenv
, curl
, cacert
, unzip
, p7zip
, qt-installer-framework-extractor
, jq
, lib
, runCommandLocal
}:
stdenv.mkDerivation rec {
  pname = "blackmagic-fairlight-sound-library";
  version = "1.0";

  src = runCommandLocal "${pname}-src.zip"
    rec {
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = "sha256-UveYl1uYcirVNCe/accO/Fn1y6+PT3KJE1pOTcwFFAA=";

      impureEnvVars = lib.fetchers.proxyImpureEnvVars;

      nativeBuildInputs = [ curl jq ];

      # ENV VARS
      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

      DOWNLOADSURL = "https://www.blackmagicdesign.com/api/support/us/downloads.json";
      SITEURL = "https://www.blackmagicdesign.com/api/register/us/download";
      PRODUCT = "Blackmagic Fairlight Sound Library";
      VERSION = version;

      USERAGENT = builtins.concatStringsSep " " [
        "User-Agent: Mozilla/5.0 (X11; Linux ${stdenv.hostPlatform.linuxArch})"
        "AppleWebKit/537.36 (KHTML, like Gecko)"
        "Chrome/77.0.3865.75"
        "Safari/537.36"
      ];

      REQJSON = builtins.toJSON {
        "firstname" = "NixOS";
        "lastname" = "Linux";
        "email" = "someone@nixos.org";
        "phone" = "+31 71 452 5670";
        "country" = "nl";
        "street" = "-";
        "state" = "Province of Utrecht";
        "city" = "Utrecht";
        "product" = PRODUCT;
        hasAgreedToTerms = true;
      };

    } ''
      read REFERID DOWNLOADID <<< $(curl --silent --compressed "$DOWNLOADSURL" \
          | jq --raw-output '.downloads[] | select(.name | test("^'"$PRODUCT $VERSION"'$")) | .urls.Linux[0] | [.releaseId, .downloadId] | join(" ")')
      echo "downloadid is $DOWNLOADID"
      test -n "$DOWNLOADID"
      RESOLVEURL=$(curl \
        --silent \
        --header 'Host: www.blackmagicdesign.com' \
        --header 'Accept: application/json, text/plain, */*' \
        --header 'Origin: https://www.blackmagicdesign.com' \
        --header "$USERAGENT" \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --header "Referer: https://www.blackmagicdesign.com/support/download/$REFERID/Linux" \
        --header 'Accept-Encoding: gzip, deflate, br' \
        --header 'Accept-Language: en-US,en;q=0.9' \
        --header 'Authority: www.blackmagicdesign.com' \
        --header 'Cookie: _ga=GA1.2.1849503966.1518103294; _gid=GA1.2.953840595.1518103294' \
        --data-ascii "$REQJSON" \
        --compressed \
        "$SITEURL/$DOWNLOADID")
      echo "resolveurl is $RESOLVEURL"

      curl \
        --retry 3 --retry-delay 3 \
        --header "Upgrade-Insecure-Requests: 1" \
        --header "$USERAGENT" \
        --header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
        --header "Accept-Language: en-US,en;q=0.9" \
        --compressed \
        "$RESOLVEURL" \
        > $out
    '';

  nativeBuildInputs = [
    unzip
    p7zip
    qt-installer-framework-extractor
  ];

  sourceRoot = ".";

  postUnpack = ''
    echo "=== Extracting makeself archive ==="
    # find offset from file
    archive=$(echo *.run)
    offset=$(${stdenv.shell} -c "$(grep -axm1 -e 'offset=.*' $archive); echo \$offset" $archive)
    echo offset is $offset
    dd if=$archive ibs=$offset skip=1 | tar -xz

    qt-installer-framework-extractor -x bin/installer
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    for i in *.7z; do
      7z x -o$out "$i"
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "500 royalty free sounds for use with the foley sampler in DaVinci Resolve";
    homepage = "https://www.blackmagicdesign.com/";
    license = licenses.unfree;
    maintainers = with maintainers; [ quentin ];
    platforms = platforms.all;
  };
}


