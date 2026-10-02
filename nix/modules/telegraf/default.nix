{ lib, pkgs, config, options, ... }@args:
let
  standalone = args ? standalone;
  isNixOS = options ? security.wrappers;
in {
  imports = builtins.filter (v: v != null) (lib.mapAttrsToList
    (name: type:
      if type == "regular" && (lib.hasSuffix ".nix" name) && name != "default.nix"
      then ./${name}
      else if type == "directory"
      then ./${name}/telegraf.nix
      else null
    )
    (builtins.readDir ./.)
  );
  options = with lib; {
    isz.telegraf = {
      enable = mkEnableOption "telegraf";
      debug = mkEnableOption "debug";
      vm = mkOption {
        type = types.bool;
        default = lib.elem "virtio_pci" (config.boot.initrd.availableKernelModules or []);
      };
      interval = mkOption {
        type = types.attrsOf (types.strMatching "[0-9]+[hms]");
      };
    } // lib.optionalAttrs (!standalone) {
      envSecrets = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Environment variables to set that contains sops placeholders";
      };
    };
  };
  config = let
    cfg = config.isz.telegraf;
  in lib.mkMerge [
    {
      _module.args = {
        inherit isNixOS;
      };
      isz.telegraf.interval = lib.mapAttrs (_: v: lib.mkOptionDefault v) {
        agent = "10s";
        cgroup = "60s";
        internal = "60s";
        sensors = "10s";
      };
    }
    (lib.mkIf cfg.enable {
      services.telegraf.enable = true;
    })
    (if isNixOS then lib.mkIf cfg.enable {
      systemd.services.telegraf = {
        wants = ["suid-sgid-wrappers.service"];
        after = ["suid-sgid-wrappers.service"];
      };
    } else {})
    (if (isNixOS && options ? sops) then lib.mkIf cfg.enable {
      sops.templates."telegraf.env" = {
        owner = config.systemd.services.telegraf.serviceConfig.User or "";
        content = lib.concatMapAttrsStringSep "\n" (name: value: "${name}=${value}") cfg.envSecrets;
      };
      systemd.services.telegraf.serviceConfig.EnvironmentFile = lib.mkIf (cfg.envSecrets != {}) [
        config.sops.templates."telegraf.env".path
      ];
    } else {})
    (if (isNixOS && options ? sops) then lib.mkIf cfg.enable {
      sops.secrets.telegraf = {
        owner = config.systemd.services.telegraf.serviceConfig.User or "";
      };
      systemd.services.telegraf.serviceConfig.EnvironmentFile = [
        config.sops.secrets.telegraf.path
      ];
      systemd.services.telegraf = {
        path = [
          pkgs.lm_sensors
          pkgs.nvme-cli
        ];
        reloadTriggers = with lib.lists;
          optional (cfg.mikrotik.api.targets != [] || cfg.mikrotik.swos.targets != []) pkgs.iszTelegraf.mikrotik
          ++ optional cfg.w1 pkgs.iszTelegraf.w1;
      };
    } else {})
    {
      services.telegraf.extraConfig = lib.mkMerge [
        {
          agent = {
            interval = cfg.interval.agent;
            round_interval = true;
            metric_batch_size = 5000;
            metric_buffer_limit = 100000;
            collection_jitter = "0s";
            flush_interval = "10s";
            flush_jitter = "0s";
            precision = "";
            inherit (cfg) debug;
            quiet = false;
            logfile = ""; # stderr
            hostname = lib.mkIf (config.networking.hostName != null) "${config.networking.hostName}.${config.networking.domain}"; # defaults to os.Hostname()
            omit_hostname = false;
            skip_processors_after_aggregators = false;
          };
          inputs = {
            cpu = [{
              percpu = true;
              totalcpu = false;
              collect_cpu_time = true;
              report_active = false;
              #core_tags = true;
            }];
            mem = [{}];
            net = [{
              tagdrop.interface = ["veth*"];
              ignore_protocol_stats = true;
            }];
            nstat = [{}];
            netstat = [{}];
            processes = [{}];
            swap = [{}];
            system = [{}];
            temp = [{
              interval = cfg.interval.sensors;
              tagdrop.sensor = ["w1_slave_temp_input"];
            }];
            internal = [{
              interval = cfg.interval.internal;
              tags.app = "telegraf";
            }];
          };
        }
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          inputs = {
            kernel = [{}];
            linux_cpu = lib.mkIf (!cfg.vm) [{}];
            cgroup = [{
              interval = cfg.interval.cgroup;
              paths = let
                f = i: if i < 0 then [] else ["/sys/fs/cgroup"] ++ (map (x: x + "/*") (f (i - 1)));
              in
                f 8;
              files = [
                "cgroup.stat"
                "cpu.stat"
                "memory.stat"
                # io.stat can't be parsed by Telegraf
              ];
            }];
            linux_sysctl_fs = [{}];
            sensors = lib.mkIf (!cfg.vm) [{
              interval = cfg.interval.sensors;
              tagdrop.chip = ["w1_slave_temp-*"];
              # Can take >5s to read when there are w1 sensors.
              timeout = "30s";
            }];
            interrupts = [{}];
          };
        })
      ];
    }
  ];
}
