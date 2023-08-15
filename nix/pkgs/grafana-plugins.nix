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
  grafana-mqtt-datasource = grafanaPlugin {
    pname = "grafana-mqtt-datasource";
    version = "1.0.0-beta.2";
    zipHash = {
      # TODO: Build from source
      x86_64-linux = "sha256-euVsBw2mMZlf7Ylw1+XFAcyJcXaTdC1EtMqyZ5p7/6c=";
      aarch64-linux = "sha256-ka9b2GZxzFtUQsMNK86F8/hOMPkdnZuoNXEwswmLN7M=";
      x86_64-darwin = "sha256-3LuSPvKGhaV9KK2O7NrmUHUJSD1mZpZ3CndgevxxQnY=";
      aarch64-darwin = "sha256-ocUZlwycLG3jK8IMaWUtNAYgMJtJGARh9R/H+gaUtaE=";
    };
  };
}
