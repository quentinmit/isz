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
        ExecStart = "${pkgs.xpra}/bin/xpra --no-daemon --bind=%t/sdrtrunk/sdrtrunk.sock --socket-permissions=660 start --start-child=${pkgs.xterm}/bin/xterm --exit-with-children=yes";
      };
    };
  };
}
