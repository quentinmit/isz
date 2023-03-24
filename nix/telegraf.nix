{ lib, pkgs, config, options, ... }:
let mikrotik-python = pkgs.callPackage ../mikrotik {}; in
{
  options = with lib; {
    isz.telegraf = {
      intelRapl = mkEnableOption "intel_rapl";
      docker = mkEnableOption "Docker";
      debug = mkEnableOption "debug";
      smartctl = mkOption {
        type = types.path;
        default = "${pkgs.smartmontools}/bin/smartctl";
      };
      openweathermap = {
        appId = mkOption {
          type = with types; nullOr str;
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
      };
    };
  };
  config = let cfg = config.isz.telegraf; in {
    systemd.services.telegraf.path = [
      pkgs.lm_sensors
      pkgs.nvme-cli
    ];
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
          smart = [{
            path_smartctl = cfg.smartctl;
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
          command = ["${pkgs.python}/bin/python" ../telegraf/scripts/intel_rapl.py];
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
        inputs.execd = map (t: {
          alias = "mikrotik_api_${t.ip}";
          command = [
            "${mikrotik-python}/bin/mikrotik_metrics.py"
            "--server"
            t.ip
            "--user"
            t.user
            "--password"
            t.password
          ] ++ (if t.plaintext then ["--plaintext-login"] else []);
          signal = "STDIN";
          interval = "30s";
          restart_delay = "10s";
          data_format = "influx";
          name_prefix = "mikrotik-";
        }) cfg.mikrotik.api.targets;
      }
      {
        inputs.execd = map (t: {
          alias = "mikrotik_swos_${t.ip}";
          command = [
            "${mikrotik-python}/bin/mikrotik_swos_metrics.py"
            "--server"
            t.ip
            "--user"
            t.user
            "--password"
            t.password
          ];
          signal = "STDIN";
          interval = "30s";
          restart_delay = "10s";
          data_format = "influx";
          name_prefix = "mikrotik-";
        }) cfg.mikrotik.swos.targets;
      }
    ];
  };
}
