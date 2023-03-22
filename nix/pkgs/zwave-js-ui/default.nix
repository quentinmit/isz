{ stdenv
, buildYarnPackage
}:

buildYarnPackage rec {
  version = "8.11.0";
  src = fetchFromGithub {
    owner = "zwave-js";
    repo = "zwave-js-ui";
    rev = "v${version}";
    sha256 = "";
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
};
