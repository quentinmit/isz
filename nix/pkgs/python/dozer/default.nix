{ lib
, buildPythonPackage
, fetchFromGitHub
, mako
, webob
, pytest
, mock
, webtest
, pillow
}:
buildPythonPackage rec {
  pname = "Dozer";
  version = "0.9.dev0";

  src = fetchFromGitHub {
    owner = "mgedmin";
    repo = "dozer";
    rev = "b968878c32be1381ce025d4e224db62fa47585ea";
    sha256 = "PsPISm9Fp2e3xft6DL0+a32R8tsd2X9n7O90D9gubdI=";
  };

  propagatedBuildInputs = [
    mako
    webob
  ];

  checkInputs = [
    pytest
    mock
    webtest
    pillow
  ];
}
