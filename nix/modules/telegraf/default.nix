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
      amdgpu = mkEnableOption "amdgpu";
      debug = mkEnableOption "debug";
      vm = mkOption {
        type = types.bool;
        default = lib.elem "virtio_pci" (config.boot.initrd.availableKernelModules or []);
      };
      openweathermap = {
        appId = mkOption {
          type = with types; nullOr str;
          default = null;
        };
        cityIds = mkOption {
          type = with types; listOf str;
          default = [];
        };
      };
      interval = mkOption {
        type = types.attrsOf (types.strMatching "[0-9]+[hms]");
      };
      influxdb.namedrop = mkOption {
        type = types.listOf types.str;
        default = [];
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
        openweathermap = "10m";
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
          processors.starlark = [{
            alias = "dropnan";
            order = 9999; # Run last
            # Work around https://github.com/influxdata/telegraf/issues/17205
            # The influxdb_v2 output drops an entire batch of metrics if there is a NaN value in any of them.
            source = ''
              load("logging.star", "log")
              nan = float('nan')

              def apply(metric):
                for k, v in metric.fields.items():
                  if v == nan:
                    metric.fields.pop(k)
                    log.warn("Dropped NaN value: metric {} field {}".format(metric.name, k))
                return metric
              '';
          }];
          outputs = {
            influxdb_v2 = [{
              # TODO: Disable https for some hosts
              urls = ["https://influx.isz.wtf"];
              token = "$INFLUX_TOKEN";
              organization = "icestationzebra";
              bucket = "icestationzebra";
              bucket_tag = "influxdb_bucket";
              exclude_bucket_tag = true;
              tagexclude = [ "greptimedb_database" ];
              timeout = "60s"; # Default timeout of 5s is sometimes too slow
              inherit (cfg.influxdb) namedrop;
            }];
            # TODO: Add option for stdout
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
        (lib.mkIf pkgs.stdenv.isLinux {
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
        (lib.mkIf cfg.amdgpu {
          inputs.execd = [{
            alias = "amdgpu";
            restart_delay = "10s";
            data_format = "influx";
            command = ["${pkgs.amdgpu}/bin/amdgpu"];
            environment = [
              #"RUST_LOG=debug"
            ];
            signal = "STDIN";
          }];
        })
        (lib.mkIf (cfg.openweathermap.appId != null && cfg.openweathermap.cityIds != []) {
          inputs.openweathermap = [{
            app_id = cfg.openweathermap.appId;
            city_id = cfg.openweathermap.cityIds;
            lang = "en";
            fetch = ["weather" "forecast"];
            interval = cfg.interval.openweathermap;
          }];
        })
      ];
    }
  ];
}
