final: prev:

{
  gcn64tools = final.callPackage ./gcn64tools {};
  dashboard = final.callPackage ../../workshop/dashboard {};
  cec = final.callPackage ../../workshop/cec {};
  rtlamr = final.callPackage ./rtlamr {};
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
      RouterOS-api = callPackage ./python/routeros-api {};
      Dozer = callPackage ./python/dozer {};
      pyweatherflowudp = callPackage ./python/pyweatherflowudp {};
      psychrolib = callPackage ./python/psychrolib {};
      hass-pyscript-kernel = callPackage ./python/hass-pyscript-kernel {};
    })
  ];
  systemd-metrics = final.callPackage ../modules/telegraf/systemd-metrics {};
  isz-mikrotik = final.callPackage ../modules/telegraf/mikrotik {};
  isz-w1 = final.callPackage ../modules/telegraf/w1 {
    inherit (final.unstable) python3;
  };
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
  };
  hassCustomComponents = {
    pyscript = final.callPackage ./homeassistant/pyscript.nix {};
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
  gotenberg = final.callPackage ./gotenberg {};
  unoconverter = final.callPackage ./gotenberg/unoconverter.nix {};
  # Can't use upstream flake, because it uses IFD.
  nix-serve-ng = (final.haskell.packages.ghc94.callPackage ./nix-serve-ng.nix {
    base16 = final.haskell.packages.ghc94.base16_1_0;
  }).overrideAttrs (old: {
    executableSystemDepends = (old.executableSystemDepends or []) ++ [
      final.boost.dev
    ];
  });
  mactelnet = final.callPackage ./mactelnet {};
  retrogram-rtlsdr = final.callPackage ./retrogram-rtlsdr {};
  sdrtrunk = final.callPackage ./sdrtrunk {};
  jmbe = final.callPackage ./sdrtrunk/jmbe {};
  xpra-html5 = final.callPackage ./xpra-html5 {
    inherit (final.nodePackages) uglify-js;
  };
  xpraFull = (final.xpra.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace xpra/server/window/windowicon_source.py \
        --replace ANTIALIAS LANCZOS
    '';
    preInstall = ''
      cp -a ${final.xpra-html5} $out
      chmod -R u+w $out
    '';
  })).override {
    pulseaudio = final.pulseaudioFull;
  };
  json2prefs = final.callPackage ../../software/json2prefs {};
}
