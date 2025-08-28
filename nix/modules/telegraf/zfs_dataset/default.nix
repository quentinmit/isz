{ lib
, stdenv
, python3
, pkgs
}:

python3.pkgs.buildPythonApplication {
  name = "zfs-influx";

  propagatedBuildInputs = with python3.pkgs; [
    influxdb-client
    py-libzfs
  ];

  src = ./.;

  format = "other";
  buildPhase = "true";
  installPhase = ''
    mkdir -p $out/bin/
    cp $src/*.py $out/bin/
  '';

  meta.mainProgram = "zfs_dataset_metrics.py";
}
