final: prev:

{
  dashboard = final.callPackage ../../workshop/dashboard {};
  rtlamr = final.callPackage ./rtlamr {};
  rtlamr-collect = final.callPackage ./rtlamr-collect {};
  speedtest-influxdb = final.callPackage ./speedtest-influxdb {};
  zwave-js-ui-bin = final.callPackage ./zwave-js-ui/bin.nix {};
  avidemux = final.libsForQt5.callPackage ./avidemux {
    inherit (final.darwin.apple_sdk.frameworks) VideoToolbox;
  };
  dns-update = final.callPackage ../../dns {};
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: with python-final; {
      RouterOS-api = callPackage ./python/routeros-api {};
      w1thermsensor = callPackage ./python/w1thermsensor {};
      Dozer = callPackage ./python/dozer {};
    })
  ];
}
