{ writers
, python3Packages
}:
writers.writePython3 "power_supply" {
  libraries = with python3Packages; [
    influxdb-client
  ];
} ./power_supply.py
