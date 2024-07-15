{ config, options, pkgs, lib, ... }:
{
  config.isz.grafana.dashboards.comcast = {
    uid = "cdr79k0uw16o0b";
    title = "Comcast";
    tags = [ "home" ];
    defaultDatasourceName = "workshop";
    graphTooltip = 1;
    panels = let
      interval = config.isz.telegraf.interval.hitron;
      mikrotikInterval = config.isz.telegraf.interval.mikrotik;
      docsisHeatmapPanel = attrs: lib.recursiveUpdate {
        panel = {
          type = "heatmap";
          inherit interval;
          options = {
            cellGap = 0;
            color.scheme = "Viridis";
            rowsFrame.layout = "ge";
            yAxis.unit = "rothz";
          };
        };
        influx = {
          fn = "mean";
          extra = ''
            |> map(fn: (r) => ({r with frequency: if exists r.Subcarr0freqFreq then r.Subcarr0freqFreq else r.frequency}))
            |> filter(fn: (r) => r.frequency != "0")
            |> keep(columns: ["_time", "_value", "frequency"])
            |> group(columns: ["frequency"])
          '';
        };
      } attrs;
    in [
      {
        panel = {
          gridPos = { x = 0; y = 0; w = 24; h = 7; };
          title = "Connection Info";
          type = "state-timeline";
          inherit interval;
          options.legend.showLegend = false;
          options.tooltip.mode = "multi";
        };
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
        panel.fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.steps = [{
            color = "#333333";
            value = null;
          }];
        };
      }
      {
        panel = {
          gridPos = { x = 0; y = 7; w = 12; h = 8; };
          title = "DHCP Remaining Lease Time";
          interval = mikrotikInterval;
        };
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
        panel.fieldConfig.defaults = {
          unit = "ns";
        };
      }
      {
        panel = {
          gridPos = { x = 0; y = 15; w = 12; h = 8; };
          title = "Comcast Throughput";
          interval = mikrotikInterval;
          options.tooltip.mode = "multi";
        };
        influx = {
          filter._measurement = "snmp-interfaces";
          filter._field = ["bytes-in" "bytes-out"];
          filter.if-name = "comcast";
          filter.hostname = "router.isz.wtf";
          fn = "derivative";
        };
        fields.bytes-in.custom.transform = "negative-Y";
        panel.fieldConfig.defaults = {
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
      }
      (docsisHeatmapPanel {
        panel.gridPos = { x = 12; y = 7; w = 12; h = 8; };
        panel.title = "DOCSIS DS Signal Strength";
        panel.options.cellValues.unit = "dBmV";
        panel.options.filterValues.le = -100;
        influx.filter._measurement = ["hitron-dsinfo" "hitron-dsofdminfo"];
        influx.filter._field = ["signalStrength" "plcpower"];
      })
      (docsisHeatmapPanel {
        panel.gridPos = { x = 12; y = 15; w = 12; h = 8; };
        panel.title = "DOCSIS DS SNR";
        panel.options.cellValues.unit = "dB";
        panel.options.filterValues.le = 1.0e-9;
        influx.filter._measurement = ["hitron-dsinfo" "hitron-dsofdminfo"];
        influx.filter._field = ["snr" "SNR"];
      })
      (docsisHeatmapPanel {
        panel.gridPos = { x = 12; y = 23; w = 12; h = 8; };
        panel.title = "DOCSIS DS Correctable Errors";
        panel.options.cellValues.unit = "Bps";
        panel.options.filterValues.le = 0;
        influx.filter._measurement = "hitron-dsinfo";
        influx.filter._field = "correcteds";
        influx.fn = "derivative";
      })
      (docsisHeatmapPanel {
        panel.gridPos = { x = 0; y = 23; w = 12; h = 8; };
        panel.title = "DOCSIS US Power";
        panel.options.cellValues.unit = "dBmV";
        panel.options.filterValues.le = 1.0e-9;
        influx.filter._measurement = "hitron-usinfo";
        influx.filter._field = "signalStrength";
      })
      {
        panel = {
          gridPos = { x = 12; y = 31; w = 12; h = 8; };
          title = "DOCSIS DS OFDM Errors";
          inherit interval;
        };
        influx = {
          filter._measurement = "hitron-dsofdminfo";
          filter._field = ["correcteds" "uncorrect"];
          fn = "derivative";
        };
        fields.bytes-in.custom.transform = "negative-Y";
        panel.fieldConfig.defaults = {
          unit = "Bps";
        };
      }
    ];
  };
}
