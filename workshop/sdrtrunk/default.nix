{ config, pkgs, lib, ... }:
{
  # TODO: Authentik
  # TODO: Audio
  # TODO: Debug empty Start menu
  # TODO: https://github.com/chuot/rdio-scanner/tree/master
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

    fonts.fontDir.enable = true;
    fonts.enableDefaultPackages = true;
    fonts.packages = with pkgs; [
      xorg.fontmiscmisc
    ];

    programs.dconf.enable = true;

    services.udev.rules = [
      {
        "ATTR{idVendor}" = "1d50"; # Great Scott Gadgets
        "ATTR{idProduct}" = "6089"; # HackRF One
        OWNER = { op = "="; value = "sdrtrunk"; };
        GROUP = { op = "="; value = "sdrtrunk"; };
      }
    ];

    systemd.services.sdrtrunk = {
      description = "SDRTrunk";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "sdrtrunk";
        Group = "sdrtrunk";
        PAMName = "login";
        RuntimeDirectory = "sdrtrunk";
        ExecStart = "${pkgs.xpraFull}/bin/xpra --no-daemon --bind=%t/sdrtrunk/sdrtrunk.sock --socket-permissions=660 start --start-child=${pkgs.xterm}/bin/xterm --exit-with-children=yes --systemd-run=no";
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

    home-manager.users.sdrtrunk = {
      home.stateVersion = "23.11";

      home.packages = with pkgs; [
        sdrtrunk
        xterm
        xorg.xev
        pavucontrol
        gnome.adwaita-icon-theme
      ];


      xdg.configFile."menus/applications.menu".text = ''
        <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
        "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">

        <Menu>
          <Name>Applications</Name>

          <!-- Search the default locations -->
          <DefaultAppDirs/>
          <DefaultDirectoryDirs/>

          <Include>
            <All />
          </Include>

          <!-- Define default layout -->
          <DefaultLayout>
            <Merge type="menus"/>
            <Merge type="files"/>
          </DefaultLayout>
        </Menu>
      '';
    };
  };
}
