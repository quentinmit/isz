{ config, pkgs, lib, ... }:
let
  inherit (pkgs) jmbe;
in {
  # TODO: Authentik
  # TODO: Debug empty Start menu
  # TODO: https://github.com/chuot/rdio-scanner/tree/master
  config = {
    users.users.sdrtrunk = {
      isSystemUser = true;
      group = "sdrtrunk";
      home = "/var/lib/sdrtrunk";
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

    services.authentik.apps.sdrtrunk = {
      name = "Radio";
      type = "proxy";
      host = "radio.isz.wtf";
      nginx = true;
    };

    systemd.services.sdrtrunk = {
      description = "SDRTrunk";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "sdrtrunk";
        Group = "sdrtrunk";
        PAMName = "login";
        RuntimeDirectory = "sdrtrunk";
        ExecStart = "${lib.getExe pkgs.xpra} --no-daemon --bind=%t/sdrtrunk/sdrtrunk.sock --socket-permissions=660 start --start-child=${lib.getExe pkgs.xterm} --exit-with-children=yes --systemd-run=no";
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
          inherit (config.services.nginx.virtualHosts."radio.isz.wtf".locations."/") extraConfig;
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
        adwaita-icon-theme
      ];

      java.userPrefs.io.github.dsheirer.preference = {
        decoder."path.jmbe.library.1.0.0" = "${jmbe}/jmbe-${jmbe.version}.jar";
        source."channelizer.type" = "HETERODYNE";
      };

      home.file."SDRTrunk/jmbe/jmbe-${jmbe.version}.jar".source = "${jmbe}/jmbe-${jmbe.version}.jar";

      home.file.".asoundrc".text = ''
        pcm_type.pulse {
          libs.native = ${pkgs.alsa-plugins}/lib/alsa-lib/libasound_module_pcm_pulse.so ;
        }
        pcm.!default {
          type pulse
          hint.description "Default Audio Device (via PulseAudio)"
        }
        ctl_type.pulse {
          libs.native = ${pkgs.alsa-plugins}/lib/alsa-lib/libasound_module_ctl_pulse.so ;
        }
        ctl.!default {
          type pulse
        }
      '';

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
