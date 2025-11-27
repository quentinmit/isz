{ lib
, stdenv
, python312
, pkgs
}:

python312.pkgs.buildPythonApplication {
  name = "zfs-influx";

  propagatedBuildInputs = with python312.pkgs; [
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
