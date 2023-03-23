{ stdenv
, lib
, fetchFromGitHub
, buildYarnPackage
}:

buildYarnPackage rec {
  version = "8.11.0";
  src = fetchFromGitHub {
    owner = "zwave-js";
    repo = "zwave-js-ui";
    rev = "v${version}";
    sha256 = "wYPUetdCkhQvgVufTcgkLAj154VK/BqMa46FwV4v7H4=";
  };

  meta = with lib; {
    description = "Z-Wave JS UI";
    longDescription = ''
      Full featured Z-Wave Control Panel UI and MQTT gateway. Built using
      Nodejs, and Vue/Vuetify.
    '';
    homepage = "https://zwave-js.github.io/zwave-js-ui/";
    license = with licenses; [ mit ];
  };
}
