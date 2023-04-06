final: prev:

{
  rtlamr = final.callPackage ./rtlamr {};
  rtlamr-collect = final.callPackage ./rtlamr-collect {};
  speedtest-influxdb = final.callPackage ./speedtest-influxdb {};
  zwave-js-ui-bin = final.callPackage ./zwave-js-ui/bin.nix {};
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      w1thermsensor = prev.callPackage ./python/w1thermsensor {};
    })
  ];
}
