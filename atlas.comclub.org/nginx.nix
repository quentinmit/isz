{ config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "qsmith@gmail.com";
  };
  systemd.services.nginx.serviceConfig = {
    AmbientCapabilities = [
      "CAP_NET_RAW"
    ];
    CapabilityBoundingSet = [
      "CAP_NET_RAW"
    ];
  };
  services.nginx = {
    enable = true;
    upstreams.hercules.servers."192.168.0.5" = {};
    virtualHosts."_" = {
      locations."/" = {
        proxyPass = "http://hercules";
        extraConfig = ''
          proxy_bind $remote_addr transparent;
        '';
      };
    };
  };
}
