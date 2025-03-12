{ lib
, fetchpatch2
, python3Packages
, fetchPypi
, nvme-cli
}:
with python3Packages;
buildPythonApplication rec {
  pname = "wd_fw_update";
  version = "2.1.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-tWtO1uJGLjVqBnPLnKzFCMPBO92Oqqg5VMvjXpHZxNk=";
  };

  postPatch = ''
    substituteInPlace src/wd_fw_update/main.py --replace '"nvme"' '"${nvme-cli}/bin/nvme"'
  '';

  format = "pyproject";

  nativeBuildInputs = [ setuptools setuptools-scm ];

  propagatedBuildInputs = [
    inquirer
    requests
    tqdm
  ];
}
