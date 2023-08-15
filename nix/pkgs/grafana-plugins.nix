{ grafanaPlugin }:
{
  fetzerch-sunandmoon-datasource = grafanaPlugin {
    pname = "fetzerch-sunandmoon-datasource";
    version = "0.3.0";
    zipHash = "sha256-zvZ8h4lM3DGr11XV2nBxmY4f+OWwQgCNrLZXoqOTBFQ=";
  };
  marcusolsson-json-datasource = grafanaPlugin {
    pname = "marcusolsson-json-datasource";
    version = "1.3.6";
    zipHash = "sha256-hZNvkqevJO47tV9S4QkAf/skqj0Gr6inoMNhvZyOZCs=";
  };
  mxswat-separator-panel = grafanaPlugin {
    pname = "mxswat-separator-panel";
    version = "1.0.1";
    zipHash = "sha256-rRWnaCX/P+joEU9kLcl8D2SFSTlmMlhvQ2/YJSFVxZ8=";
  };
  operato-windrose-panel = grafanaPlugin {
    pname = "operato-windrose-panel";
    version = "1.1.0";
    zipHash = "sha256-uYCYV1cv7zRG53J22bP5KCjFYPPp+58ZLn6KVDEqYug=";
    postPatch = ''
      rm MANIFEST.txt
    '';
  };
}
