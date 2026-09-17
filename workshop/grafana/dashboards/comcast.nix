{ config, options, pkgs, lib, ... }:
let
  interval = config.isz.telegraf.interval.hitron;
  mikrotikInterval = config.isz.telegraf.interval.mikrotik;
  docsisHeatmapPanelModule = {
    spec.vizConfig.group = "heatmap";
    spec.vizConfig.spec.options = {
      cellGap = 0;
      color.scheme = "Viridis";
      rowsFrame.layout = "ge";
      yAxis.unit = "rothz";
    };
    influx = {
      fn = lib.mkDefault "mean";
      extra = ''
        |> map(fn: (r) => ({r with frequency: if exists r.Subcarr0freqFreq then r.Subcarr0freqFreq else r.frequency}))
        |> filter(fn: (r) => r.frequency != "0")
        |> keep(columns: ["_time", "_value", "frequency"])
        |> group(columns: ["frequency"])
      '';
    };
  };
in {
  config.isz.grafana.dashboardsV2.cdr79k0uw16o0b = { config, ... }: {
    options = {
      panels = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          config.spec.data.spec.queryOptions.interval = lib.mkDefault interval;
        });
      };
    };
    config = {
      title = "Comcast";
      tags = [ "home" ];
      defaultDatasourceName = "workshop";
      spec.cursorSync = "Crosshair";
      layout.kind = "GridLayout";
      layout.spec.items = [
        { spec = {
            element.name = "connection-state-timeline";
            x = 0; y = 0; width = 24; height = 7;
          }; }
        { spec = {
            element.name = "dhcp-lease-time";
            x = 0; y = 7; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "comcast-throughput";
            x = 0; y = 15; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "docsis-ds-rssi";
            x = 12; y = 7; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "docsis-ds-snr";
            x = 12; y = 15; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "docsis-ds-correctable";
            x = 12; y = 23; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "docsis-us-power";
            x = 0; y = 23; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "modem-uptime";
            x = 0; y = 31; width = 12; height = 8;
          }; }
        { spec = {
            element.name = "docsis-ds-ofdm";
            x = 12; y = 31; width = 12; height = 8;
          }; }
      ];
      panels.connection-state-timeline = {
        spec.title = "Connection Info";
        spec.vizConfig.group = "state-timeline";
        spec.vizConfig.spec.options.legend.showLegend = false;
        spec.vizConfig.spec.options.tooltip.mode = "multi";
        influx = [
          {
            imports = ["strings"];
            filter._measurement = ["mikrotik-/ipv6/dhcp-client" "mikrotik-/ip/dhcp-client"];
            filter._field = [
              "dhcp-server"
              "dhcp-server-v6"
              "gateway"
              "primary-dns"
              "secondary-dns"
              "address"
              "prefix"
            ];
            filter.interface = "comcast";
            fn = "last";
            extra = ''
                |> map(fn: (r) => ({
                  r with
                  type:
                    if strings.split(t: "/", v: r._measurement)[1] == "ipv6"
                    then "DHCPv6"
                    else "DHCP"
                }))
                |> keep(columns: ["_measurement", "_field", "type", "_time", "_value"])
                |> group(columns: ["_measurement", "_field", "type"])
            '';
            options.displayName = "\${__field.labels.type} \${__field.name}";
          }
          {
            filter._measurement = ["hitron-sysinfo" "hitron-docsis"];
            filter._field = [
              "swVersion"
              "Configname"
              "CmGateway"
              "CmIpAddress"
              "CmNetMask"
              "NetworkAccess"
            ];
            fn = "last";
            options.displayName = "\${__field.name}";
          }
        ];
        spec.vizConfig.spec.fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.steps = [{
            color = "#333333";
            value = null;
          }];
        };
      };
      panels.dhcp-lease-time = {
        spec.title = "DHCP Remaining Lease Time";
        spec.data.spec.queryOptions.interval = mikrotikInterval;
        influx = [
          {
            filter._measurement = "mikrotik-/ip/dhcp-client";
            filter._field = "expires-after-ns";
            filter.interface = "comcast";
            fn = "mean";
            options.displayName = "IPv4";
          }
          {
            filter._measurement = "mikrotik-/ipv6/dhcp-client";
            filter._field = "prefix-expires-after-ns";
            filter.interface = "comcast";
            fn = "mean";
            options.displayName = "IPv6";
          }
        ];
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "ns";
        };
      };
      panels.comcast-throughput = {
        spec.title = "Comcast Throughput";
        spec.data.spec.queryOptions.interval = mikrotikInterval;
        spec.vizConfig.spec.options.tooltip.mode = "multi";
        influx = {
          filter._measurement = "snmp-interfaces";
          filter._field = ["bytes-in" "bytes-out"];
          filter.if-name = "comcast";
          filter.hostname = "router.isz.wtf";
          fn = "derivative";
        };
        fields.bytes-in.custom.transform = "negative-Y";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "Bps";
          max = 100000000;
          min = -100000000;
          custom.axisLabel = "in (-) / out (+)";
          custom.scaleDistribution = {
            type = "symlog";
            log = 10;
            linearThreshold = 1000;
          };
          custom.fillOpacity = 10;
        };
      };
      panels.docsis-ds-rssi = { ... }: {
        imports = [ docsisHeatmapPanelModule ];
        spec.title = "DOCSIS DS Signal Strength";
        spec.vizConfig.spec.options.cellValues.unit = "dBmV";
        spec.vizConfig.spec.options.filterValues.le = -100;
        influx.filter._measurement = ["hitron-dsinfo" "hitron-dsofdminfo"];
        influx.filter._field = ["signalStrength" "plcpower"];
      };
      panels.docsis-ds-snr = { ... }: {
        imports = [ docsisHeatmapPanelModule ];
        spec.title = "DOCSIS DS SNR";
        spec.vizConfig.spec.options.cellValues.unit = "dB";
        spec.vizConfig.spec.options.filterValues.le = 1.0e-9;
        influx.filter._measurement = ["hitron-dsinfo" "hitron-dsofdminfo"];
        influx.filter._field = ["snr" "SNR"];
      };
      panels.docsis-ds-correctable = { ... }: {
        imports = [ docsisHeatmapPanelModule ];
        spec.title = "DOCSIS DS Correctable Errors";
        spec.vizConfig.spec.options.cellValues.unit = "Bps";
        spec.vizConfig.spec.options.filterValues.le = 0;
        influx.filter._measurement = "hitron-dsinfo";
        influx.filter._field = "correcteds";
        influx.fn = "derivative";
      };
      panels.docsis-us-power = { ... }: {
        imports = [ docsisHeatmapPanelModule ];
        spec.title = "DOCSIS US Power";
        spec.vizConfig.spec.options.cellValues.unit = "dBmV";
        spec.vizConfig.spec.options.filterValues.le = 1.0e-9;
        influx.filter._measurement = "hitron-usinfo";
        influx.filter._field = "signalStrength";
      };
      panels.modem-uptime = {
        spec.title = "Modem Uptime";
        spec.data.spec.queryOptions.interval = mikrotikInterval;
        influx = {
          filter._measurement = "hitron-sysinfo";
          filter._field = "systemUptime";
          fn = "last";
        };
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "s";
        };
      };
      panels.docsis-ds-ofdm = {
        spec.title = "DOCSIS DS OFDM Errors";
        influx = {
          filter._measurement = "hitron-dsofdminfo";
          filter._field = ["correcteds" "uncorrect"];
          fn = "derivative";
        };
        fields.bytes-in.custom.transform = "negative-Y";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "Bps";
        };
      };
    };
  };
}
