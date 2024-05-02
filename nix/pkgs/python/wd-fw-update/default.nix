{ lib
, fetchpatch2
, python3Packages
, fetchPypi
, nvme-cli
}:
with python3Packages;
buildPythonApplication rec {
  pname = "wd_fw_update";
  version = "1.2.1";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-iZdHQ9qOVyUY2/JPqO0TPvL/wQc2b/4tIUmEuJZhIq4=";
  };

  patches = [
    (fetchpatch2 {
      url = "https://github.com/not-a-feature/wd_fw_update/pull/2.patch";
      hash = "sha256-3RkhGMmcKuhiMpWgy/gfDD6NKZhWrupd7VZpmznNsn4=";
    })
  ];

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
