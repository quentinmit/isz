final: prev:

{
  gcn64tools = final.callPackage ./gcn64tools {};
  dashboard = final.callPackage ../../workshop/dashboard {};
  cec = final.callPackage ../../workshop/cec {};
  rtlamr-collect = final.callPackage ./rtlamr-collect {};
  speedtest-influxdb = final.callPackage ./speedtest-influxdb {};
  zwave-js-ui-bin = final.callPackage ./zwave-js-ui/bin.nix {};
  avidemux = if final.stdenv.isDarwin then (final.libsForQt5.callPackage ./avidemux {
    inherit (final.darwin.apple_sdk_11_0.frameworks) VideoToolbox CoreFoundation CoreMedia CoreVideo CoreAudio CoreServices QuartzCore;
    stdenv = if final.stdenv.isDarwin then final.darwin.apple_sdk_11_0.stdenv else final.stdenv;
  }) else prev.avidemux;
  macfuse = final.callPackage ./macfuse {
    inherit (final.darwin.apple_sdk.frameworks) DiskArbitration;
    inherit (final.darwin) signingUtils;
  };
  macfuse-stubs = final.macfuse;
  snmp-mibs = final.callPackage ./snmp-mibs {};
  dns-update = final.callPackage ../../dns {};
  process-bandwidth = final.callPackage ./process-bandwidth {};
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: with python-final; {
      Dozer = callPackage ./python/dozer {};
      pyweatherflowudp = callPackage ./python/pyweatherflowudp {};
      hass-pyscript-kernel = callPackage ./python/hass-pyscript-kernel {};
      simplepam = callPackage ./python/simplepam {};
      vcgencmd = callPackage ./python/vcgencmd {};
      piscsi-common = callPackage ./piscsi/common.nix {};
      inventree = callPackage ./python/inventree {};
      mouser = callPackage ./python/mouser {};
      kiutils = callPackage ./python/kiutils {};
      wrapt_timeout_decorator = callPackage ./python/wrapt_timeout_decorator {};
      cli_exit_tools = callPackage ./python/cli_exit_tools {};
      lib_detect_testenv = callPackage ./python/lib_detect_testenv {};
      ionit = callPackage ./python/ionit {};
      ymodem = callPackage ./python/ymodem {};
    })
  ];
  systemd-metrics = final.callPackage ../modules/telegraf/systemd-metrics {};
  amdgpu = final.callPackage ../../amdgpu {};
  rx_tools = final.callPackage ./rx_tools {};
  ialauncher = final.callPackage ./python/ialauncher {};
  monaco-nerd-fonts = final.callPackage ./monaco-nerd-fonts {};
  git-fullstatus = final.callPackage ./git-fullstatus {};
  weatherflow2mqtt = final.callPackage ./python/weatherflow2mqtt {};
  grafanaPlugins = prev.grafanaPlugins // prev.grafanaPlugins.callPackage ./grafana-plugins.nix {};
  home-assistant-custom-lovelace-modules = prev.home-assistant-custom-lovelace-modules // {
    compass-card = final.callPackage ./homeassistant/compass-card.nix {};
    layout-card = final.callPackage ./homeassistant/layout-card.nix {};
    restriction-card = final.callPackage ./homeassistant/restriction-card.nix {};
    hui-element = final.callPackage ./homeassistant/hui-element.nix {};
  };
  home-assistant-custom-components = prev.home-assistant-custom-components // {
    pyscript = final.home-assistant.python.pkgs.callPackage ./homeassistant/pyscript.nix {};
    bambu_lab = final.home-assistant.python.pkgs.callPackage ./homeassistant/bambu_lab.nix {};
    pirateweather = final.home-assistant.python.pkgs.callPackage ./homeassistant/pirateweather.nix {};
  };
  cisco-mibs = final.fetchFromGitHub {
    owner = "cisco";
    repo = "cisco-mibs";
    rev = "0ddd4b1dfa82dd32b2b98185e584e39e69d26e96";
    hash = "sha256-XAWKhPWvtc/iSf4Dlz+dJt5a9uxZM8T/SYEYqeFSwW0=";
  };
  equivs = final.callPackage ./equivs {};
  debhelper = final.callPackage ./debhelper {};
  knockd = final.callPackage ./knockd {};
  knock = final.knockd.override {
    withKnockd = false;
  };
  mactelnet = final.callPackage ./mactelnet {
    inherit (final.darwin.apple_sdk.frameworks) SystemConfiguration;
  };
  retrogram-rtlsdr = final.callPackage ./retrogram-rtlsdr {};
  sdrtrunk = final.callPackage ./sdrtrunk {};
  jmbe = final.callPackage ./sdrtrunk/jmbe {};
  json2prefs = final.callPackage ../../software/json2prefs {};
  boxy-svg = final.callPackage ./boxy-svg {};
  iszTelegraf = let
    inherit (final) lib;
    dir = builtins.readDir ../modules/telegraf;
    paths = lib.mapAttrs (name: _: ../modules/telegraf/${name}/default.nix) dir;
    files = lib.filterAttrs (_: path: lib.pathExists path) paths;
  in lib.makeScope final.newScope (self: lib.mapAttrs (_: file: self.callPackage file {}) files);
  vscode-extensions = prev.vscode-extensions // {
    Surendrajat.apklab = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "apklab";
      publisher = "Surendrajat";
      version = "1.7.0";
      hash = "sha256-9QC56sK7GLqtRuloHX9nb6N8+VAkGCqA2sNMgHK04Oo=";
      meta.license = final.lib.licenses.agpl3Only;
    };
    LoyieKing.smalise = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "smalise";
      publisher = "LoyieKing";
      version = "0.0.12";
      hash = "sha256-GZjurKTwqGO5Hxv6HYxHr9Sy+srZMxOsialL8B+kjV8=";
      meta.license = final.lib.licenses.mit;
    };
    ms-playwright.playwright = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "playwright";
      publisher = "ms-playwright";
      version = "1.1.5";
      hash = "sha256-DAqQSEUdMCw2sFJeAiXgZOJadZyWCYdbRJP1mUd9YCg=";
      meta.license = final.lib.licenses.asl20;
    };
    savonet.vscode-liquidsoap = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "vscode-liquidsoap";
      publisher = "savonet";
      version = "0.1.1";
      hash = "sha256-mLiXHIkKZ32fKWF9Rao/QZwySskV5L4XGcgp+AWBIMI=";
      meta.license = final.lib.licenses.mit;
    };
    eclipse-cdt.peripheral-inspector = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "peripheral-inspector";
      publisher = "eclipse-cdt";
      version = "1.8.1";
      hash = "sha256-sk4F1UXNFq7bNYrWLAW7DxbXMUQGQUZh61UjIa+lfA4=";
      meta.license = final.lib.licenses.mit;
    };
    eclipse-cdt.cdt-gdb-vscode = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "cdt-gdb-vscode";
      publisher = "eclipse-cdt";
      version = "2.2.0";
      hash = "sha256-5KtpPyaMFZ5kxKZUpcHj9/tTYQ6eonGbP4LbycF1NmI=";
      meta.license = final.lib.licenses.mit;
    };
    marus25.cortex-debug = let
      publisher = "marus25";
      name = "cortex-debug";
      platformInfix = "";
      platformSuffix = "";
      version = "1.13.0-pre6";
    in final.vscode-utils.buildVscodeMarketplaceExtension {
      mktplcRef = {
        inherit publisher name version;
      };
      vsix = final.fetchurl {
        name = "${publisher}-${name}.zip";
        url = "https://open-vsx.org/api/${publisher}/${name}${platformInfix}/${version}/file/${publisher}.${name}-${version}${platformSuffix}.vsix";
        hash = "sha256-nr5yRzPsnpDuCEz0J5Lb9Nfb4zipDifNDGhsHHFFzoY=";
      };
    };
    mcu-debug.debug-tracker-vscode = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "debug-tracker-vscode";
      publisher = "mcu-debug";
      version = "0.0.15";
      hash = "sha256-2u4Moixrf94vDLBQzz57dToLbqzz7OenQL6G9BMCn3I=";
      meta.license = final.lib.licenses.mit;
    };
    mcu-debug.memory-view = final.vscode-utils.extensionFromVscodeMarketplace {
      name = "memory-view";
      publisher = "mcu-debug";
      version = "0.0.25";
      hash = "sha256-Tck3MYKHJloiXChY/GbFvpBgLBzu6yFfcBd6VTpdDkc=";
      meta.license = final.lib.licenses.mit;
    };
    ms-vscode = prev.vscode-extensions.ms-vscode // {
      mock-debug = final.vscode-utils.extensionFromVscodeMarketplace {
        name = "mock-debug";
        publisher = "ms-vscode";
        version = "0.52.0";
        hash = "sha256-l+00y6xJt7vAS8kv6PjBMwUJCNG1ZgFsMQoGXlC6J88=";
        meta.license = final.lib.licenses.mit;
      };
    };
  };
  wd-fw-update = final.callPackage ./python/wd-fw-update {};
  dwex = final.callPackage ./python/dwex {};
  einstein = final.callPackage ./einstein {};
  input-utils = final.callPackage ./input-utils {};
  sheepshaver = final.callPackage ./sheepshaver {};
  fairlight-sound-library = final.callPackage ./blackmagic/fairlight-sound-library.nix {};
  qt-installer-framework-extractor = final.callPackage ./qt-installer-framework-extractor {};
  segger-systemview = final.callPackage ./segger-systemview {};
  apple-fonts = final.callPackages ./apple-fonts {};
  piscsi = final.callPackage ./piscsi {};
  hfsutils = final.callPackage ./hfsutils {};
  hfdisk = final.callPackage ./hfdisk {};
  fdt-viewer = final.qt6Packages.callPackage ./fdt-viewer {};
  jellyfin-plugin-sso = final.callPackage ./jellyfin-plugin-sso {};
  unleashed-recomp = final.unstable.callPackage ./unleashed-recomp {};
  hedge-mod-manager = final.callPackage ./hedge-mod-manager {};
  plasma-homeassistant = final.callPackage ./plasma-homeassistant {};
  kintree = final.callPackage ./python/kintree {};
  bsproxy = final.callPackage ../../software/bsproxy {};
  lisaem = final.callPackage ./lisaem {};
  orangepi-firmware = final.callPackage ./orangepi-firmware {};
  xgpro = final.callPackage ./xgpro {};
  ltchiptool = final.callPackage ./python/ltchiptool {};
}
