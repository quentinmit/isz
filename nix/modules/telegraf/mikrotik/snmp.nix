{ lib, pkgs, config, options, ...}@args:
let
  cfg = config.isz.telegraf.mikrotik.snmp;
in {
  options = with lib; {
    isz.telegraf.mikrotik.snmp = let trg = with types; submodule {
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
  config.services.telegraf.extraConfig = lib.mkIf (cfg.targets != []) {
    agent.snmp_translator = "gosmi";
    inputs.snmp = map (host: {
      alias = "mikrotik_snmp_${host.ip}";
      agents = [ "${host.ip}:161" ];
      timeout = "1s";
      retries = 1;

      path = [
        "${pkgs.runCommand "mikrotik-mibs" {} ''
          mkdir $out
          cp "${pkgs.cisco-mibs}/v2/"{SNMPv2-SMI.my,SNMPv2-TC.my,INET-ADDRESS-MIB.my} $out/
          cp "${./mikrotik.mib}" $out/mikrotik.mib
        ''}"
      ];

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
            { name = "if-index"; oid = ".1.3.6.1.2.1.2.2.1.1"; is_tag = true; }
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
        { # Gauges
          name = "snmp-mikrotik-gauges";
          inherit_tags = ["hostname"];
          field = [
            { name = "name"; oid = ".1.3.6.1.4.1.14988.1.1.3.100.1.2"; is_tag = true; }
            { name = "unit"; oid = ".1.3.6.1.4.1.14988.1.1.3.100.1.4"; conversion = "enum"; is_tag = true; }

            { name = "value"; oid = ".1.3.6.1.4.1.14988.1.1.3.100.1.3"; }
          ];
        }
      ];
    }) cfg.targets;
    processors.starlark = [{
      namepass = ["snmp-mikrotik-gauges"];
      source = ''
        def apply(metric):
          name = metric.tags.pop("name")
          value = metric.fields.pop("value")
          unit = metric.tags.get("unit")
          if unit and unit[0] == "d":
            value /= 10.
            metric.tags["unit"] = unit[1:]
          metric.fields[name] = value
          return metric
      '';
    }];
  };
}
