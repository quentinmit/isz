{ buildPythonPackage
, protobuf
, requests
, setuptools
, piscsi
, lib
, bridge-utils
, coreutils
, hfsutils
, multipath-tools
, dosfstools
, hfdisk
, hxtools
, util-linux
, unzip
, unixtools
, cdrkit
, unar
, pkgs
}:
buildPythonPackage {
  pname = "piscsi-common";
  inherit (piscsi) src version;
  sourceRoot = "source/python/common";

  # Upstream doesn't ship a proper pyproject.toml.
  format = "pyproject";
  patches = [
    ./0003-common-paths.patch
  ];
  patchFlags = "-p3";
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
    substituteInPlace src/piscsi/sys_cmds.py \
      --replace-fail '"ps"' '"${lib.getExe unixtools.ps}"' \
      --replace-fail '"brctl"' '"${lib.getExe' bridge-utils "brctl"}"' \
      --replace-fail '"hostnamectl"' '"${lib.getExe' pkgs.systemd "hostnamectl"}"' \
      --replace-fail '"journalctl"' '"${lib.getExe' pkgs.systemd "journalctl"}"' \
      --replace-fail '"disktype"' '"${lib.getExe' util-linux "partx"}", "--show", "-v", "--output-all"' \
      --replace-fail '"man2html"' '"${lib.getExe' hxtools "man2html"}"'
    substituteInPlace src/util/unarchiver.py \
      --replace-fail '"unar"' '"${lib.getBin unar}/bin/unar"' \
      --replace-fail '"lsar"' '"${lib.getBin unar}/bin/lsar"'
  '';
  nativeBuildInputs = [
    protobuf
    setuptools
  ];
  preConfigure = ''
    protoc -I=../../proto --python_out=./src piscsi_interface.proto
  '';

  propagatedBuildInputs = [
    protobuf
    requests
  ];
}
