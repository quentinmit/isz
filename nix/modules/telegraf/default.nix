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
      docker = mkEnableOption "Docker";
      amdgpu = mkEnableOption "amdgpu";
      debug = mkEnableOption "debug";
      smart.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SMART monitoring";
      };
      smart.smartctl = mkOption {
        type = with types; nullOr path;
        default = "${pkgs.smartmontools}/bin/smartctl";
      };
      smart.nvme = mkOption {
        type = with types; nullOr path;
        default = null;
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
      prometheus.apps = let
        interval = config.isz.telegraf.interval.prometheus;
        app = with types; submodule ({ name, config, ... }: {
          options = {
            url = mkOption { type = str; };
            tags = mkOption { type = attrsOf str; };
            extraConfig = mkOption { type = attrs; };
          };
          config = {
            tags.app = lib.mkDefault name;
            extraConfig = {
              alias = name;
              urls = [config.url];
              metric_version = 2;
              inherit interval;
              inherit (config) tags;
            };
          };
        });
      in mkOption {
        type = with types; attrsOf app;
        default = {};
      };
      postgresql = mkEnableOption "PostgreSQL support";
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
        prometheus = "60s";
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
    (if isNixOS then lib.mkIf (cfg.enable && cfg.smart.enable) {
      isz.telegraf.smart.smartctl = lib.mkDefault "/run/wrappers/bin/smartctl_telegraf";
      isz.telegraf.smart.nvme = lib.mkDefault "/run/wrappers/bin/nvme_telegraf";
      security.wrappers.smartctl_telegraf = lib.mkIf (cfg.smart.smartctl != null) {
        source = "${pkgs.smartmontools}/bin/smartctl";
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
      security.wrappers.nvme_telegraf = lib.mkIf (cfg.smart.nvme != null) {
        source = "${pkgs.nvme-cli}/bin/nvme";
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
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
    (if isNixOS then lib.mkIf (cfg.enable && cfg.postgresql) {
      services.postgresql = {
        ensureUsers = [{
          name = "telegraf";
          ensureDBOwnership = true;
        }];
        ensureDatabases = [ "telegraf" ];
      };
    } else {})
    {
      services.telegraf.extraConfig = lib.mkMerge [
        {
          agent = {
            interval = cfg.interval.agent;
            round_interval = true;
            metric_batch_size = 5000;
            metric_buffer_limit = 50000;
            collection_jitter = "0s";
            flush_interval = "10s";
            flush_jitter = "0s";
            precision = "";
            inherit (cfg) debug;
            quiet = false;
            logfile = ""; # stderr
            hostname = lib.mkIf (config.networking.hostName != null) "${config.networking.hostName}.${config.networking.domain}"; # defaults to os.Hostname()
            omit_hostname = false;
          };
          outputs = {
            influxdb_v2 = [{
              # TODO: Disable https for some hosts
              urls = ["https://influx.isz.wtf"];
              token = "$INFLUX_TOKEN";
              organization = "icestationzebra";
              bucket = "icestationzebra";
              bucket_tag = "influxdb_bucket";
              exclude_bucket_tag = true;
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
            disk = [{
              ignore_fs = ["tmpfs" "devtmpfs" "devfs" "overlay" "aufs" "squashfs"];
            }];
            diskio = [{}];
            mem = [{}];
            net = [{
              tagdrop.interface = ["veth*"];
              ignore_protocol_stats = true;
            }];
            nstat = [{}];
            netstat = [{}];
            processes = [{}];
            smart = lib.mkIf cfg.smart.enable [{
              path_smartctl = lib.mkIf (cfg.smart.smartctl != null) cfg.smart.smartctl;
              path_nvme = lib.mkIf (cfg.smart.nvme != null) cfg.smart.nvme;
              attributes = true;
            }];
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
            sensors = [{
              interval = cfg.interval.sensors;
              tagdrop.chip = ["w1_slave_temp-*"];
              # Can take >5s to read when there are w1 sensors.
              timeout = "30s";
            }];
            interrupts = [{}];
          };
        })
        (lib.mkIf cfg.docker {
          inputs.docker = [{
            endpoint = "unix:///var/run/docker.sock";
            gather_services = false;
            container_names = [];
            container_name_include = [];
            container_name_exclude = [];
            timeout = "5s";
            perdevice = true;
            total = false;
            docker_label_include = [];
            docker_label_exclude = [];
          }];
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
        (lib.mkIf (cfg.prometheus.apps != {}) {
          inputs.prometheus = lib.mapAttrsToList (_: value: value.extraConfig) cfg.prometheus.apps;
        })
        (lib.mkIf cfg.postgresql {
          inputs.postgresql = [{
            address = "postgresql://";
          }];
        })
      ];
    }
  ];
}
