{ writers
, python3Packages
}:
writers.writePython3 "drm" {
  libraries = [ python3Packages.influxdb-client ];
} ./drm.py
