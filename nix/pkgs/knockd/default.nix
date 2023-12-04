{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
, libpcap
, withKnockd ? true
}:

stdenv.mkDerivation rec {
  pname = "knockd";
  version = "0.8";

  src = fetchFromGitHub {
    owner = "jvinet";
    repo = "knock";
    rev = "v${version}";
    hash = "sha256-GOg6wovyr6J5qHm5EsOxrposFtwwx/FyJs7g0dagFmk=";
  };

  nativeBuildInputs = [
    autoreconfHook
  ];

  buildInputs = lib.optionals withKnockd [
    libpcap
  ];

  configureFlags = lib.optionals (!withKnockd) [
    "--disable-knockd"
  ];

  meta = with lib; {
    description = "A port-knocking daemon";
    homepage = "https://github.com/jvinet/knock";
    changelog = "https://github.com/jvinet/knock/blob/${src.rev}/ChangeLog";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ "quentin" ];
    mainProgram = "knock";
    platforms = platforms.all;
  };
}
