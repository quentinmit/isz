final: prev:

{
  dashboard = final.callPackage ../../workshop/dashboard {};
  cec = final.callPackage ../../workshop/cec {};
  rtlamr = final.callPackage ./rtlamr {};
  rtlamr-collect = final.callPackage ./rtlamr-collect {};
  speedtest-influxdb = final.callPackage ./speedtest-influxdb {};
  zwave-js-ui-bin = final.callPackage ./zwave-js-ui/bin.nix {};
  avidemux = final.libsForQt5.callPackage ./avidemux {
    inherit (final.darwin.apple_sdk_11_0.frameworks) VideoToolbox CoreFoundation CoreMedia CoreVideo CoreAudio CoreServices QuartzCore;
    stdenv = if final.stdenv.isDarwin then final.darwin.apple_sdk_11_0.stdenv else final.stdenv;
  };
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
  hassLovelaceModules = {
    compass-card = final.callPackage ./homeassistant/compass-card.nix {};
    layout-card = final.callPackage ./homeassistant/layout-card.nix {};
  };
  hassCustomComponents = {
    pyscript = final.callPackage ./homeassistant/pyscript.nix {};
  };
}
