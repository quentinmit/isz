{ lib
, buildPythonPackage
, fetchPypi
, pkgs
, setuptools
, aiofiles
, click
, coverage
, tomli
, pytest
, pytest-mock
, pytest-asyncio
, pytestCheckHook
, pythonOlder
}:
buildPythonPackage rec {
  pname = "w1thermsensor";
  version = "2.0.0";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-EcaEr4B8icbwZu2Ty3z8AAgglf74iZ5BLpLnSOZC2cE=";
  };

  postPatch = ''
    sed -i 's/3\.5\.\*/3.5/' setup.py
  '';

  nativeBuildInputs = [
    setuptools
  ];

  # Don't try to load the kernel module in tests.
  W1THERMSENSOR_NO_KERNEL_MODULE = 1;

  nativeCheckInputs = [
    coverage
    pytest-mock
    pytest-asyncio
    pytestCheckHook
  ] ++ lib.optionals (pythonOlder "3.11") [
    tomli
  ];

  pythonImportsCheck = [
    "w1thermsensor"
  ];

  propagatedBuildInputs = [ aiofiles click ];

  meta = with lib; {
    description = "Python interface to 1-Wire temperature sensors";
    longDescription = ''
      A Python package and CLI tool to work with w1 temperature sensors like
      DS1822, DS18S20 & DS18B20 on the Raspberry Pi, Beagle Bone and other
      devices.
    '';
    homepage = "https://github.com/timofurrer/w1thermsensor";
    license = licenses.mit;
    maintainers = [ maintainers.quentin ];
    platforms = platforms.all;
  };
}
