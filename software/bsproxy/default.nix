{ writers
}:
writers.writePython3Bin "bsproxy" {} (builtins.readFile ./bsproxy.py)
