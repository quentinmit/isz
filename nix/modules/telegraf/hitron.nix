{ lib, config, ... }:
let
  cfg = config.isz.telegraf.hitron;
  interval = config.isz.telegraf.interval.hitron;
in {
  options = with lib; {
    isz.telegraf.hitron = let trg = with types; submodule {
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
  config = {
    isz.telegraf.interval.hitron = lib.mkOptionDefault "60s";
    services.telegraf.extraConfig = lib.mkIf (cfg.targets != []) {
      inputs.http = lib.concatMap (host: [
        {
          alias = "hitron_${host.ip}_dsinfo";
          inherit interval;
          tags = { agent_host = "${host.ip}"; };
          tagexclude = ["url"];
          urls = [
            "https://${host.ip}/data/dsinfo.asp"
          ];
          insecure_skip_verify = true;
          data_format = "json_v2";
          json_v2 = [{
            measurement_name = "hitron-dsinfo";
            object = [{
              path = "@this";
              tags = [
                "portId"
                "frequency"
                "channelId"
                "modulation"
              ];
              fields = {
                signalStrength = "float";
                snr = "float";
              };
            }];
          }];
        }
        {
          alias = "hitron_${host.ip}_usinfo";
          inherit interval;
          tags = { agent_host = "${host.ip}"; };
          tagexclude = ["url"];
          urls = [
            "https://${host.ip}/data/usinfo.asp"
          ];
          insecure_skip_verify = true;
          data_format = "json_v2";
          json_v2 = [{
            measurement_name = "hitron-usinfo";
            object = [{
              path = "@this";
              tags = [
                "portId"
                "frequency"
                "channelId"
                "modtype"
                "scdmaMode"
              ];
              fields = {
                bandwidth = "int";
                signalStrength = "float";
              };
            }];
          }];
        }
        {
          alias = "hitron_${host.ip}_dsofdminfo";
          inherit interval;
          tags = { agent_host = "${host.ip}"; };
          tagexclude = ["url"];
          urls = [
            "https://${host.ip}/data/dsofdminfo.asp"
          ];
          insecure_skip_verify = true;
          data_format = "json_v2";
          json_v2 = [{
            measurement_name = "hitron-dsofdminfo";
            object = [{
              path = "@this";
              tags = [
                "receive"
                "Subcarr0freqFreq"
                "ffttype"
              ];
              fields = {
                SNR = "float";
                plcpower = "float";
              };
            }];
          }];
        }
        # TODO: usofdminfo
        # {"uschindex":"0","state":"  DISABLED","frequency":"0","digAtten":"    0.0000","digAttenBo":"    0.0000","channelBw":"    0.0000","repPower":"    0.0000","repPower1_6":"    0.0000","fftVal":"2K"}
        {
          alias = "hitron_${host.ip}_getCmDocsisWan";
          inherit interval;
          tags = { agent_host = "${host.ip}"; };
          tagexclude = ["url"];
          urls = [
            "https://${host.ip}/data/getCmDocsisWan.asp"
          ];
          insecure_skip_verify = true;
          data_format = "json_v2";
          json_v2 = [{
            measurement_name = "hitron-docsis";
            object = [{
              path = "@this";
              excluded_keys = [
                # Always `D: -- H: -- M: -- S: --`
                "CmIpLeaseDuration"
              ];
            }];
          }];
        }
        {
          alias = "hitron_${host.ip}_getSysInfo";
          inherit interval;
          tags = { agent_host = "${host.ip}"; };
          tagexclude = ["url"];
          urls = [
            "https://${host.ip}/data/getSysInfo.asp"
          ];
          insecure_skip_verify = true;
          data_format = "json_v2";
          json_v2 = [{
            measurement_name = "hitron-sysinfo";
            object = [{
              path = "@this";
              tags = [
                "hwVersion"
                "rfMac"
                "serialNumber"
              ];
              excluded_keys = [
                # These just contain `TODO`
                "LRecPkt"
                "LSendPkt"
                "WRecPkt"
                "WSendPkt"
                "lanIp"
                "wanIp"
                # This just contains `--`
                "timezone"
              ];
            }];
          }];
        }
      ]) cfg.targets;
      processors.strings = [
        {
          namepass = ["hitron-dsofdminfo"];
          trim = [{
            tag = "Subcarr0freqFreq";
          }];
        }
      ];
      processors.enum = [
        {
          namepass = ["hitron-dsinfo"];
          mapping = [{
            tag = "modulation";
            value_mappings = {
              "0" = "16QAM";
              "1" = "64QAM";
              "2" = "256QAM";
              "3" = "1024QAM";
              "4" = "32QAM";
              "5" = "128QAM";
              "6" = "QPSK";
            };
          }];
        }
        {
          namepass = ["hitron-dsofdminfo"];
          mapping = map (field: {
            inherit field;
            value_mappings = {
              "YES" = true;
              "NO" = false;
            };
          }) ["mdc1lock" "ncplock" "plclock"];
        }
      ];
      processors.starlark = [
        {
          namepass = ["hitron-dsinfo" "hitron-dsofdminfo"];
          source = ''
            def fixOctets(metric):
              for field in ["correcteds", "uncorrect", "dsoctets"]:
                if field in metric.fields:
                  value = metric.fields[field]
                  parts = value.split(" * 2e32 + ")
                  out = int(parts[-1])
                  if len(parts) > 1:
                    out += int(parts[0]) << 32
                  metric.fields[field] = out
            def apply(metric):
              fixOctets(metric)
              return [metric]
          '';
        }
        {
          namepass = ["hitron-sysinfo"];
          source = ''
            def fixUptime(metric):
              if "systemUptime" in metric.fields:
                parts = metric.fields["systemUptime"].split(":")
                out = 0.0
                for part in parts:
                  value = int(part[:-1])
                  if part[-1] == "s":
                    out += value
                  elif part[-1] == "m":
                    out += value * 60
                  elif part[-1] == "h":
                    out += value * 3600
                  else:
                    print("Unknown unit", part)
                    return
                metric.fields["systemUptime"] = out
            def apply(metric):
              fixUptime(metric)
              return [metric]
          '';
        }
      ];
    };
  };
}
