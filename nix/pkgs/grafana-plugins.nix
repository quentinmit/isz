{ grafanaPlugin }:
{
  fetzerch-sunandmoon-datasource = grafanaPlugin {
    pname = "fetzerch-sunandmoon-datasource";
    version = "0.3.3";
    zipHash = "sha256-IJe1OiPt9MxqqPymuH0K27jToSb92M0P4XGZXvk0paE=";
  };
  marcusolsson-json-datasource = grafanaPlugin {
    pname = "marcusolsson-json-datasource";
    version = "1.3.16";
    zipHash = "sha256-KusBAJKqpuwVgKhrSjvYeStJsmKPTwhDQiX9B5MKkpc=";
  };
  operato-windrose-panel = grafanaPlugin {
    pname = "operato-windrose-panel";
    version = "1.2.0";
    zipHash = "sha256-fOejV+rLzgj3Zsm6x1OXbk5IqJPNkKXchsWNfDrXe2E=";
    postPatch = ''
      rm MANIFEST.txt
    '';
  };
  grafana-mqtt-datasource = grafanaPlugin {
    pname = "grafana-mqtt-datasource";
    version = "1.1.0-beta.2";
    zipHash = {
      # TODO: Build from source
      aarch64-linux = "sha256-cquaTD3e40vj7PuQDHvODHOpXeWx3AaN6Mv+Vu+ikbI=";
      aarch64-darwin = "sha256-9FP7UbNI4q4nqRTzlNKcEPnJ9mdqzOL4E0nuEAdFNJw=";
      x86_64-linux = "sha256-QYv+6zDLSYiB767A3ODgZ1HzPd7Hpa90elKDV1+dNx8=";
      x86_64-darwin = "sha256-PZmUkghYawU5aKA536u3/LCzsvkIFVJIzl1FVWcrKTI=";
    };
  };
  volkovlabs-echarts-panel = grafanaPlugin {
    pname = "volkovlabs-echarts-panel";
    version = "6.2.0";
    zipHash = "sha256-JjCUpSP3YJ7be0QHJdZUzzJxggbqByF18tBcTAHE6Fw=";
  };
}
