{ buildPythonPackage
, protobuf
, requests
, setuptools
, piscsi
}:
buildPythonPackage {
  pname = "piscsi-common";
  inherit (piscsi) src version;
  sourceRoot = "source/python/common";

  # Upstream doesn't ship a proper pyproject.toml.
  format = "pyproject";
  postPatch = ''
    cat >>pyproject.toml <<EOF

    [project]
    name = "piscsi-common"
    version = "${piscsi.version}"
    dependencies = [
      "protobuf",
      "requests",
    ]
    EOF
  '';
  nativeBuildInputs = [
    protobuf
    setuptools
  ];
  preConfigure = ''
    protoc -I=../../cpp --python_out=./src piscsi_interface.proto
  '';

  propagatedBuildInputs = [
    protobuf
    requests
  ];
}
