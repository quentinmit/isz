{ pkgs, lib }:
lib.makeScope pkgs.newScope (self: with self; {
  intelRapl = pkgs.writers.writePython3 "intel_rapl" {} (lib.readFile ./intel_rapl.py);
  powerSupply = pkgs.writers.writePython3 "power_supply" {} (lib.readFile ./power_supply.py);
  drm = pkgs.writers.writePython3 "drm" {
    libraries = [ pkgs.python3Packages.influxdb-client ];
  } (lib.readFile ./drm.py);
})
