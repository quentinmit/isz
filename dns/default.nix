{ lib
, python3Packages
}:
with python3Packages;
buildPythonApplication rec {
  pname = "dns-update";
  version = "0.0.1";
  format = "pyproject";

  propagatedBuildInputs = [
    RouterOS-api
    toml
    dnspython
    frozendict
    setuptools
    netaddr
  ];

  src = ./.;
}
