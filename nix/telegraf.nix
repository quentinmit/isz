{ lib, pkgs, config, options, ... }:
let mikrotik-python = pkgs.isz-mikrotik; in
{
  options = with lib; {
    isz.telegraf = {
      enable = mkEnableOption "telegraf";
      intelRapl = mkEnableOption "intel_rapl";
      docker = mkEnableOption "Docker";
      debug = mkEnableOption "debug";
      smartctl = mkOption {
        type = with types; nullOr path;
        default = "/run/wrappers/bin/smartctl_telegraf";
      };
      nvme = mkOption {
        type = types.path;
        default = "/run/wrappers/bin/nvme_telegraf";
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
              type = with types; listOf (trg);
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
              type = with types; listOf (trg);
            };
          };
        snmp = let trg = with types; submodule {
            options = {
              ip = mkOption { type = str; };
            };
          }; in {
            targets = mkOption {
              default = [];
              type = with types; listOf (trg);
            };
          };
      };
      w1 = mkEnableOption "1-Wire support";
    };
  };
  config = let cfg = config.isz.telegraf; in lib.mkMerge [
    (lib.mkIf cfg.enable {
      security.wrappers.smartctl_telegraf = lib.mkIf (cfg.smartctl != null) {
        source = "${pkgs.smartmontools}/bin/smartctl";
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
      security.wrappers.nvme_telegraf = {
        source = "${pkgs.nvme-cli}/bin/nvme";
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
      sops.secrets.telegraf = {
        owner = config.systemd.services.telegraf.serviceConfig.User;
      };
      services.telegraf.enable = true;
      systemd.services.telegraf.serviceConfig.EnvironmentFile = [
        config.sops.secrets.telegraf.path
      ];
      systemd.services.telegraf = {
        path = [
          pkgs.lm_sensors
          pkgs.nvme-cli
        ];
      };
    })
    (lib.mkIf (cfg.enable && cfg.intelRapl) {
      security.wrappers.intel_rapl_telegraf = let
      intelRapl = pkgs.writers.writePython3 "intel_rapl" {} (lib.readFile ../telegraf/scripts/intel_rapl.py);
      in {
        source = intelRapl;
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
    })
    {
      services.telegraf.extraConfig = lib.mkMerge [
        {
            agent = {
            interval = "10s";
            round_interval = true;
            metric_batch_size = 5000;
            metric_buffer_limit = 50000;
            collection_jitter = "0s";
            flush_interval = "10s";
            flush_jitter = "0s";
            precision = "";
            debug = cfg.debug;
            quiet = false;
            logfile = ""; # stderr
            hostname = "${config.networking.hostName}.${config.networking.domain}"; # defaults toos.Hostname()
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
            smart = lib.mkIf (cfg.smartctl != null) [{
              path_smartctl = cfg.smartctl;
              path_nvme = cfg.nvme;
              attributes = true;
            }];
            swap = [{}];
            system = [{}];
            temp = [{
              tagdrop.sensor = ["w1_slave_temp_input"];
            }];
            internal = [{
              interval = "60s";
              tags.app = "telegraf";
            }];
          };
        }
        (lib.mkIf pkgs.stdenv.isLinux {
          inputs = {
            kernel = [{}];
            cgroup = [{
              interval = "60s";
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
            interval = "10m";
          }];
        })
        {
          inputs.execd = map (host: {
            alias = "mikrotik_api_${host.ip}";
            command = [
              "${mikrotik-python}/bin/mikrotik_metrics.py"
              "--server"
              host.ip
              "--user"
              host.user
              "--password"
              host.password
            ] ++ (if host.plaintext then ["--plaintext-login"] else []);
            signal = "STDIN";
            interval = "30s";
            restart_delay = "10s";
            data_format = "influx";
            name_prefix = "mikrotik-";
          }) cfg.mikrotik.api.targets;
        }
        {
          inputs.execd = map (host: {
            alias = "mikrotik_swos_${host.ip}";
            command = [
              "${mikrotik-python}/bin/mikrotik_swos_metrics.py"
              "--server"
              host.ip
              "--user"
              host.user
              "--password"
              host.password
            ];
            signal = "STDIN";
            interval = "30s";
            restart_delay = "10s";
            data_format = "influx";
            name_prefix = "mikrotik-";
          }) cfg.mikrotik.swos.targets;
        }
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
            command = ["${pkgs.isz-w1}/bin/w1_metrics.py"];
            signal = "STDIN";
            restart_delay = "10s";
            data_format = "influx";
          }];
        })
      ];
    }
  ];
}
