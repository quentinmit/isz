{ lib
, jinja2
, pyyaml
, buildPythonPackage
, fetchPypi
, setuptools
}:

buildPythonPackage rec {
  pname = "ionit";
  version = "0.5.1";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-L+wK3lJA9kLV+CsCSHj9UrdUiyv3cmn7Cdvjmo7Bv1g=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  dependencies = [
    jinja2
    pyyaml
  ];

  meta = with lib; {
    homepage = "https://github.com/bdrung/ionit";
    license = licenses.isc;
    description = "Render configuration files from Jinja templates";
    maintainers = [ maintainers.quentin ];
  };
}
