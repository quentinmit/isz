{ writers
, python3Packages
}:
writers.writePython3Bin "qt-installer-framework-extractor" {
  libraries = with python3Packages; [
    kaitaistruct
  ];
  flakeIgnore = [
    "E301" # blank lines
    "E302"
    "E303"
    "E305"
    "E501" # long lines
  ];
} ./extract.py
