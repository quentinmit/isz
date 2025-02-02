{ stdenv
, fetchFromGitHub
, autoreconfHook
, lib
}:
stdenv.mkDerivation {
  pname = "hfsutils";
  version = "3.2.6";

  src = fetchFromGitHub {
    owner = "JotaRandom";
    repo = "hfsutils";
    rev = "9aeaf911d40d8f2abbfe5ca6db2d5b873bc149d2";
    hash = "sha256-XGZRRTHhzjvfiOANzArPFnHyx6DvbT/JXaMOOgOhtGs=";
  };

  nativeBuildInputs = [
    autoreconfHook
  ];

  preBuild = ''
    makeFlagsArray+=(AR="${stdenv.cc.targetPrefix}ar rc")
  '';

  meta = with lib; {
    description = "Tools for reading and writing Macintosh volumes";
    homepage = "https://www.mars.org/home/rob/proj/hfs/";
    license = licenses.gpl2;
    maintainers = [ maintainers.quentin ];
    platforms = platforms.unix;
  };
}
