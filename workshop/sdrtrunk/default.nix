{ config, pkgs, lib, ... }:
{
  config = {
    users.users.sdrtrunk = {
      isSystemUser = true;
      group = "sdrtrunk";
      home = "/var/lib/sdtrunk";
      homeMode = "755";
      createHome = true;
      useDefaultShell = true;
    };
    users.groups.sdrtrunk = {};
    users.users."${config.services.nginx.user}".extraGroups = [ "sdrtrunk" ];

    systemd.services.sdrtrunk = {
      description = "SDRTrunk";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "sdrtrunk";
        Group = "sdrtrunk";
        PAMName = "login";
        RuntimeDirectory = "sdrtrunk";
        ExecStart = "${pkgs.xpra-with-html5}/bin/xpra --no-daemon --bind=%t/sdrtrunk/sdrtrunk.sock --socket-permissions=660 start --start-child=${pkgs.xterm}/bin/xterm --exit-with-children=yes";
      };
    };

    services.nginx = {
      upstreams.sdrtrunk.servers."unix:/run/sdrtrunk/sdrtrunk.sock" = {};
      virtualHosts."radio.isz.wtf" = {
        forceSSL = true;
        enableACME = true;
        locations."/sdrtrunk/" = {
          proxyPass = "http://sdrtrunk/";
          proxyWebsockets = true;
        };
        locations."=/sdrtrunk/default-settings.txt" = {
          alias = pkgs.writeText "default-settings.txt" ''
            blocked-hosts = xpra.org,www.xpra.org
            min-quality = 10
            min-speed = 50
            ssl = 1
          '';
        };
      };
    };
  };
}
