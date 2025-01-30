{ stdenv
, pkg-config
, spdlog
, libpcap
, protobuf
, fetchFromGitHub
}: let
  pname = "piscsi";
  version = "24.04.01";
in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "PiSCSI";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-6KiL+ExtiHMjO/bEIBIui4y1pOE1yvepB8ti2mt7EzQ=";
  };
  sourceRoot = "source/cpp";

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail "-lprotobuf" '$(shell $(PKG_CONFIG) --libs protobuf)'
    substituteInPlace ../os_integration/piscsi.service \
      --replace-fail /usr/local $out
  '';

  nativeBuildInputs = [
    protobuf
    pkg-config
  ];

  buildInputs = [
    spdlog
    libpcap
    protobuf
  ];

  makeFlags = [
    "CONNECT_TYPE=FULLSPEC"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];

  preInstall = ''
    installFlagsArray+=(
      "USR_LOCAL_BIN=$out/bin"
      "MAN_PAGE_DIR=$out/share/man/man1"
      "SYSTEMD_CONF=$out/lib/systemd/system/piscsi.service"
      "RSYSLOG_CONF="
      "RSYSLOG_LOG="
    )
    mkdir -p $out/bin $out/share/man/man1 $out/lib/systemd/system
  '';

  enableParallelBuilding = true;
}
