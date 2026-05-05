{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.papd;
  papdConfFile = pkgs.writeText "papd.conf" (lib.concatStringsSep "\n" (lib.mapAttrsToList (_: value: value._config) cfg.printers));
in
{
  options = {
    services.papd = {
      enable = lib.mkEnableOption "the Netatalk PAP printing daemon";

      printers = lib.mkOption {
        default = {};
        type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
          options = {
            type = lib.mkOption {
              type = lib.types.str;
              default = "LaserWriter";
            };
            zone = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
            };
            uams = lib.mkOption {
              type = with lib.types; nullOr (listOf str);
              default = null;
              description = "List of UAMs to use for authentication. To disable authentication, set to null.";
            };
            cupsOptions = lib.mkOption {
              type = with lib.types; attrsOf (oneOf [bool str]);
              default = {};
              description = "Options to pass through to CUPS.";
            };
            printer = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "CUPS printer or pipe destination.";
            };
            operator = lib.mkOption {
              type = lib.types.str;
              default = "operator";
              description = "User to spool job as";
            };
            _config = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              visible = false;
            };
          };
          config = let
            auth = lib.optionals (config.uams != null) ["au" "am=${lib.concatStringsSep "," config.uams}"];
            cupsOptions = lib.mapAttrsToList (key: value: "co=\"${if value == true then key else "${key}=${value}"}\"") config.cupsOptions;
            printer = ["pr=${config.printer}"];
            nbpName = "${name}:${config.type}${lib.optionalString (config.zone != null) "@${config.zone}"}";
          in {
            _config = lib.concatStringsSep ":" ([ nbpName ] ++ auth ++ cupsOptions ++ printer ++ [ "op=${config.operator}" ]);
          };
        }));
        description = ''
          Printers to expose via PAP.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-papd" = {
      "/var/spool/netatalk".d = {
        user = "root";
        group = "lp";
        mode = "0710";
      };
    };

    systemd.services.papd = {
      description = "Netatalk PAP printing daemon for AppleTalk clients";
      unitConfig.Documentation = "man:papd.conf(5) man:netatalk(8) man:papd(8)";
      after = [
        "atalkd.service"
        "network.target"
      ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.netatalk ];

      serviceConfig = {
        Type = "forking";
        GuessMainPID = "no";
        PIDFile = "/run/papd/papd";
        RuntimeDirectory = "papd";
        BindPaths = [ "/run/papd:/run/lock" ];
        ExecStart = "${pkgs.netatalk}/sbin/papd -f ${papdConfFile}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP  $MAINPID";
        ExecStop = "${pkgs.coreutils}/bin/kill -TERM $MAINPID";
        Restart = "always";
        RestartSec = 1;
      };
    };
  };
}
