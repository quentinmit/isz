{ lib, pkgs, config, options, ... }@args:
let
  isz-mikrotik = pkgs.callPackage ./mikrotik {};
  isz-w1 = pkgs.callPackage ./w1 {
    python3 = pkgs.unstable.python3;
  };
  # nix-darwin exposes "nixos" as a field on lib, but NixOS does not (??).
  isNixDarwin = lib ? nixos;
in {
  imports = if isNixDarwin then [ ./darwin.nix ] else [];
  options = with lib; {
    isz.telegraf = {
      enable = mkEnableOption "telegraf";
      docker = mkEnableOption "Docker";
      intelRapl = mkEnableOption "intel_rapl";
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
        default = {
          agent = "10s";
          cgroup = "60s";
          mikrotik = "30s";
          internal = "60s";
          openweathermap = "10m";
        };
      };
      mikrotik = {
        api = let trg = with types; submodule {
            options = {
              ip = mkOption { type = str; };
              user = mkOption { type = str; };
              password = mkOption { type = str; };
              plaintext = mkOption { type = bool; default = false; };
            };
          }; in {
            targets = mkOption {
              default = [];
              type = with types; listOf trg;
            };
          };
        swos = let trg = with types; submodule {
            options = {
              ip = mkOption { type = str; };
              user = mkOption { type = str; };
              password = mkOption { type = str; };
            };
          }; in {
            targets = mkOption {
              default = [];
              type = with types; listOf trg;
            };
          };
        snmp = let trg = with types; submodule {
            options = {
              ip = mkOption { type = str; };
            };
          }; in {
            targets = mkOption {
              default = [];
              type = with types; listOf trg;
            };
          };
      };
      w1 = mkEnableOption "1-Wire support";
    };
  };
  config = let
    cfg = config.isz.telegraf;
    isNixOS = builtins.hasAttr "wrappers" options.security;
  in lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.telegraf.enable = true;
    })
    (if isNixOS then lib.mkIf cfg.smart.enable {
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
    (if isNixOS then lib.mkIf cfg.enable {
      sops.secrets.telegraf = {
        owner = config.systemd.services.telegraf.serviceConfig.User;
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
          optional (cfg.mikrotik.api.targets != [] || cfg.mikrotik.swos.targets != []) isz-mikrotik
          ++ optional cfg.w1 isz-w1;
      };
    } else {})
    (if isNixOS then let
      intelRapl = pkgs.writers.writePython3 "intel_rapl" {} (lib.readFile ./intel_rapl.py);
    in lib.mkIf (cfg.enable && cfg.intelRapl) {
      security.wrappers.intel_rapl_telegraf = {
        source = intelRapl;
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
      systemd.services.telegraf.reloadTriggers = [intelRapl];
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
            }];
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
            }];
            linux_sysctl_fs = [{}];
            sensors = [{
              tagdrop.chip = ["w1_slave_temp-*"];
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
        (lib.mkIf cfg.intelRapl {
          inputs.execd = [{
            alias = "intel_rapl";
            restart_delay = "10s";
            data_format = "influx";
            command = ["/run/wrappers/bin/intel_rapl_telegraf"];
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
        (lib.mkIf (cfg.mikrotik.api.targets != []) {
          inputs.execd = map (host: {
            alias = "mikrotik_api_${host.ip}";
            command = [
              "${isz-mikrotik}/bin/mikrotik_metrics.py"
              "--server"
              host.ip
              "--user"
              host.user
              "--password"
              host.password
            ] ++ (if host.plaintext then ["--plaintext-login"] else []);
            signal = "STDIN";
            interval = cfg.interval.mikrotik;
            restart_delay = "10s";
            data_format = "influx";
            name_prefix = "mikrotik-";
          }) cfg.mikrotik.api.targets;
        })
        (lib.mkIf (cfg.mikrotik.swos.targets != []) {
          inputs.execd = map (host: {
            alias = "mikrotik_swos_${host.ip}";
            command = [
              "${isz-mikrotik}/bin/mikrotik_swos_metrics.py"
              "--server"
              host.ip
              "--user"
              host.user
              "--password"
              host.password
            ];
            signal = "STDIN";
            interval = cfg.interval.mikrotik;
            restart_delay = "10s";
            data_format = "influx";
            name_prefix = "mikrotik-";
          }) cfg.mikrotik.swos.targets;
        })
        (lib.mkIf (cfg.mikrotik.snmp.targets != []) {
          inputs.snmp = map (host: {
            alias = "mikrotik_snmp_${host.ip}";
            agents = [ "${host.ip}:161" ];
            timeout = "1s";
            retries = 1;
  
            field = [
              { name = "hostname"; oid = ".1.3.6.1.2.1.1.5.0"; is_tag = true; }
  
              { name = "uptime"; oid = ".1.3.6.1.2.1.1.3.0"; }
              { name = "cpu-frequency"; oid = ".1.3.6.1.4.1.14988.1.1.3.14.0"; }
              { name = "cpu-load"; oid = ".1.3.6.1.2.1.25.3.3.1.2.1"; }
              { name = "active-fan"; oid = ".1.3.6.1.4.1.14988.1.1.3.9.0"; }
              { name = "voltage"; oid = ".1.3.6.1.4.1.14988.1.1.3.8.0"; conversion = "float(1)"; }
              { name = "temperature"; oid = ".1.3.6.1.4.1.14988.1.1.3.10.0"; conversion = "float(1)"; }
              { name = "processor-temperature"; oid = ".1.3.6.1.4.1.14988.1.1.3.11.0"; conversion = "float(1)"; }
              { name = "current"; oid = ".1.3.6.1.4.1.14988.1.1.3.13.0"; }
              { name = "fan-speed"; oid = ".1.3.6.1.4.1.14988.1.1.3.17.0"; }
              { name = "fan-speed2"; oid = ".1.3.6.1.4.1.14988.1.1.3.18.0"; }
              { name = "power-consumption"; oid = ".1.3.6.1.4.1.14988.1.1.3.12.0"; }
              { name = "psu1-state"; oid = ".1.3.6.1.4.1.14988.1.1.3.15.0"; }
              { name = "psu2-state"; oid = ".1.3.6.1.4.1.14988.1.1.3.16.0"; }
            ];
  
            table = [
              { # Interfaces
                name = "snmp-interfaces";
                inherit_tags = ["hostname"];
                field = [
                  { name = "if-name"; oid = ".1.3.6.1.2.1.2.2.1.2"; is_tag = true; }
                  { name = "mac-address"; oid = ".1.3.6.1.2.1.2.2.1.6"; is_tag = true; conversion = "hwaddr"; }
  
                  { name = "actual-mtu"; oid = ".1.3.6.1.2.1.2.2.1.4"; }
                  { name = "admin-status"; oid = ".1.3.6.1.2.1.2.2.1.7"; }
                  { name = "oper-status"; oid = ".1.3.6.1.2.1.2.2.1.8"; }
                  { name = "bytes-in"; oid = ".1.3.6.1.2.1.31.1.1.1.6"; }
                  { name = "packets-in"; oid = ".1.3.6.1.2.1.31.1.1.1.7"; }
                  { name = "discards-in"; oid = ".1.3.6.1.2.1.2.2.1.13"; }
                  { name = "errors-in"; oid = ".1.3.6.1.2.1.2.2.1.14"; }
                  { name = "bytes-out"; oid = ".1.3.6.1.2.1.31.1.1.1.10"; }
                  { name = "packets-out"; oid = ".1.3.6.1.2.1.31.1.1.1.11"; }
                  { name = "discards-out"; oid = ".1.3.6.1.2.1.2.2.1.19"; }
                  { name = "errors-out"; oid= ".1.3.6.1.2.1.2.2.1.20"; }
  
                  # PoE (part of interfaces table above)
                  { name = "poe-out-status"; oid = ".1.3.6.1.4.1.14988.1.1.15.1.1.3"; }
                  { name = "poe-out-voltage"; oid = ".1.3.6.1.4.1.14988.1.1.15.1.1.4"; conversion = "float(1)"; }
                  { name = "poe-out-current"; oid = ".1.3.6.1.4.1.14988.1.1.15.1.1.5"; }
                  { name = "poe-out-power"; oid = ".1.3.6.1.4.1.14988.1.1.15.1.1.6"; conversion = "float(1)"; }
                ];
              }
              { # Wireless interfaces
                name = "snmp-wireless-interfaces";
                inherit_tags = ["hostname"];
                field = [
                  { name = "ssid"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.4"; is_tag = true; }
                  { name = "bssid"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.5"; is_tag = true; }
  
                  { name = "tx-rate"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.2"; }
                  { name = "rx-rate"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.3"; }
                  { name = "client-count"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.6"; }
                  { name = "frequency"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.7"; }
                  { name = "band"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.8"; }
                  { name = "noise-floor"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.9"; }
                  { name = "overall-ccq"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.10"; }
                  { name = "auth-client-count"; oid = ".1.3.6.1.4.1.14988.1.1.1.3.1.6"; }
                ];
              }
              { # Wireless registrations
                name = "snmp-wireless-registrations";
                inherit_tags = ["hostname"];
                field = [
                  { name = "mac-address"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.1"; is_tag = true; conversion = "hwaddr"; }
                  { name = "radio-name"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.20"; is_tag = true; }
  
                  { name = "signal-strength"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.3"; }
                  { name = "tx-bytes"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.4"; }
                  { name = "rx-bytes"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.5"; }
                  { name = "tx-packets"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.6"; }
                  { name = "rx-packets"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.7"; }
                  { name = "tx-rate"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.8"; }
                  { name = "rx-rate"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.9"; }
                  { name = "routeros-version"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.10"; }
                  { name = "uptime"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.11"; }
                  { name = "signal-to-noise"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.12"; }
                  { name = "tx-signal-strength-ch0"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.13"; }
                  { name = "rx-signal-strength-ch0"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.14"; }
                  { name = "tx-signal-strength-ch1"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.15"; }
                  { name = "rx-signal-strength-ch1"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.16"; }
                  { name = "tx-signal-strength-ch2"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.17"; }
                  { name = "rx-signal-strength-ch2"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.18"; }
                  { name = "tx-signal-strength"; oid = ".1.3.6.1.4.1.14988.1.1.1.2.1.19"; }
                ];
              }
              { # Memory usage (storage/RAM)
                name = "snmp-memory-usage";
                inherit_tags = ["hostname"];
                field = [
                  { name = "memory-name"; oid = ".1.3.6.1.2.1.25.2.3.1.3"; is_tag = true; }
  
                  { name = "total-memory"; oid = ".1.3.6.1.2.1.25.2.3.1.5"; }
                  { name = "used-memory"; oid = ".1.3.6.1.2.1.25.2.3.1.6"; }
                ];
              }
            ];
          }) cfg.mikrotik.snmp.targets;
        })
        (lib.mkIf cfg.w1 {
          inputs.execd = [{
            alias = "w1";
            command = ["${isz-w1}/bin/w1_metrics.py"];
            signal = "STDIN";
            restart_delay = "10s";
            data_format = "influx";
          }];
        })
      ];
    }
  ];
}
