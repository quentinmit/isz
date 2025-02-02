{ buildPythonPackage
, protobuf
, requests
, setuptools
, piscsi
, lib
, coreutils
, hfsutils
, multipath-tools
, dosfstools
, hfdisk
, util-linux
, unzip
, cdrkit
, unar
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
    substituteInPlace src/piscsi/file_cmds.py \
      --replace-fail '"dd"' '"${lib.getBin coreutils}/bin/dd"' \
      --replace-fail '"hformat"' '"${lib.getBin hfsutils}/bin/hformat"' \
      --replace-fail '"kpartx"' '"${lib.getBin multipath-tools}/bin/kpartx"' \
      --replace-fail '"mkfs.fat"' '"${lib.getBin dosfstools}/bin/mkfs.fat"' \
      --replace-fail '"hfdisk"' '"${lib.getBin hfdisk}/bin/hfdisk"' \
      --replace-fail '"fdisk"' '"${lib.getBin util-linux}/bin/fdisk"' \
      --replace-fail '"unzip"' '"${lib.getBin unzip}/bin/unzip"' \
      --replace-fail '"genisoimage"' '"${lib.getBin cdrkit}/bin/genisoimage"'
    substituteInPlace src/util/unarchiver.py \
      --replace-fail '"unar"' '"${lib.getBin unar}/bin/unar"' \
      --replace-fail '"lsar"' '"${lib.getBin unar}/bin/lsar"'
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
