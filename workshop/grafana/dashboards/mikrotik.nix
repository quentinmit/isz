{ config, pkgs, lib, ... }:
with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
{
  config.isz.grafana.dashboards.Mikrotik = {
    uid = "mikrotik";
    title = "Mikrotik";
    defaultDatasourceName = "workshop";
    graphTooltip = 2;
    variables.hostname = {
      predicate = ''r["_measurement"] == "mikrotik-/interface"'';
      extra.label = "Host";
    };
    panels = let
      firewallGraph = key: attrs: lib.recursiveUpdate {
        panel.fieldConfig.defaults = {
          unit = "bps";
          displayName = "\${__field.labels.chain} | \${__field.labels.rule}";
        };
        influx.filter._measurement = ["mikrotik-/ipv6/firewall/${key}" "mikrotik-/ip/firewall/${key}"];
        influx.filter._field = "bytes";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "derivative";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: 8. * r._value}))
          |> map(fn: (r) => ({r with rule: if exists r.comment then r.comment else r.rule}))
        '';
      } attrs;
    in [
      {
        panel.title = "System";
        panel.type = "row";
        panel.gridPos = { x = 0; y = 0; w = 24; h = 1; };
      }
      {
        panel.title = "Identity";
        panel.gridPos = { x = 0; y = 1; w = 2; h = 3; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Routerboard HW";
        panel.gridPos = { x = 2; y = 1; w = 3; h = 2; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Installed Packages";
        panel.gridPos = { x = 5; y = 1; w = 5; h = 7; };
        panel.type = "table";
        # TODO
      }
      {
        panel.gridPos = { x = 10; y = 1; w = 4; h = 7; };
        panel.type = "bargauge";
        panel.fieldConfig.defaults = {
          decimals = 1;
          max = 100;
          min = 0;
          unit = "percent";
          color.mode = "thresholds";
          thresholds.steps = [
            { value = null; color = "rgba(50, 172, 45, 0.97)"; }
            { value = 70; color = "rgba(237, 129, 40, 0.89)"; }
            { value = 90; color = "rgba(245, 54, 54, 0.9)"; }
          ];
        };
        panel.options = {
          displayMode = "lcd";
        };
        influx = [
          {
            filter._measurement = "snmp-memory-usage";
            filter._field = ["total-memory" "used-memory"];
            filter.hostname = "\${hostname}";
            fn = "last1";
            pivot = true;
            extra = ''
              |> map(fn: (r) => ({
                "memory-name": r["memory-name"],
                _time: r._time,
                _value: float(v: r["used-memory"])/float(v: r["total-memory"])*100.0
              }))
            '';
          }
          {
            filter._measurement = "snmp";
            filter._field = "cpu-load";
            filter.hostname = "\${hostname}";
            fn = "last1";
            groupBy.fn = "mean";
          }
        ];
        # Used RAM memory
        # HDD Utilization
        # TODO: CPU Load
      }
      {
        panel.title = "CPU Load";
        panel.gridPos = { x = 14; y = 1; w = 5; h = 7; };
        influx.filter._measurement = "snmp";
        influx.filter._field = "cpu-load";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          unit = "percent";
        };
      }
      {
        panel.title = "CPU Frequency";
        panel.gridPos = { x = 19; y = 1; w = 5; h = 7; };
        influx.filter._measurement = "snmp";
        influx.filter._field = "cpu-frequency";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          unit = "MHz";
        };
      }
      {
        panel.title = "CPU";
        panel.gridPos = { x = 2; y = 3; w = 3; h = 2; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Temperature";
        panel.gridPos = { x = 0; y = 4; w = 2; h = 6; };
        panel.type = "gauge";
        influx.filter._measurement = "snmp-mikrotik-gauges";
        influx.filter.unit = "celsius";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.groupBy = {
          fields = [];
          fn = "max1";
        };
        panel.fieldConfig.defaults = {
          unit = "celsius";
          min = 0;
          max = 100;
          color.mode = "thresholds";
          thresholds.steps = [
            { value = null; color = "blue"; }
            { value = 30; color = "green"; }
            { value = 60; color = "yellow"; }
            { value = 70; color = "orange"; }
            { value = 80; color = "red"; }
          ];
        };
      }
      {
        panel.title = "System version";
        panel.gridPos = { x = 2; y = 5; w = 3; h = 3; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Uptime";
        panel.gridPos = { x = 2; y = 8; w = 3; h = 2; };
        panel.type = "stat";
        influx.filter._measurement = "snmp";
        influx.filter._field = "uptime";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: float(v: r._value)/100.0}))
        '';
        panel.fieldConfig.defaults = {
          unit = "dtdurations";
        };
      }
      {
        panel.title = "Active Users";
        panel.gridPos = { x = 5; y = 8; w = 9; h = 7; };
        panel.type = "table";
        # TODO
      }
      {
        panel.title = "Memory Utilization";
        panel.gridPos = { x = 14; y = 9; w = 10; h = 7; };
        panel.fieldConfig.defaults = {
          unit = "decbytes";
        };
        influx.filter._measurement = "snmp-memory-usage";
        influx.filter._field = ["total-memory" "used-memory"];
        influx.filter.memory-name = "main memory";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";

        fields."total-memory" = {
          color.fixedColor = "#E24D42";
          color.mode = "fixed";
          custom.fillOpacity = 20;
          custom.lineWidth = 0;
        };
        fields."used-memory" = {
          color.fixedColor = "#1F78C1";
          color.mode = "fixed";
        };
      }
      {
        panel.title = "Voltage";
        panel.gridPos = { x = 0; y = 10; w = 2; h = 2; };
        panel.type = "stat";
        panel.fieldConfig.defaults = {
          unit = "volt";
        };
        influx.filter._measurement = "snmp";
        influx.filter._field = "voltage";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
      }
      {
        panel.title = "IP Address";
        panel.gridPos = { x = 2; y = 10; w = 3; h = 2; };
        panel.type = "stat";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.interface}";
        };
        panel.options.reduceOptions.fields = "/.*/";
        influx.filter._measurement = "mikrotik-/ip/address";
        influx.filter._field = "address";
        influx.filter.disabled = "false";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.extra = ''
          |> keep(columns: ["interface", "_value"])
        '';
      }
      {
        panel.title = "Public Address";
        panel.gridPos = { x = 0; y = 12; w = 5; h = 3; };
        panel.type = "stat";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.interface}";
        };
        panel.options.reduceOptions.fields = "/.*/";
        influx.filter._measurement = "mikrotik-/ip/address";
        influx.filter._field = "address";
        influx.filter.disabled = "false";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.extra = ''
          |> keep(columns: ["interface", "_value"])
        '';
      }

      {
        panel.title = "DHCP";
        panel.gridPos = { x = 0; y = 15; w = 24; h = 1; };
        panel.type = "row";
      }
      {
        panel.title = "IP Pool Usage";
        panel.gridPos = { x = 0; y = 16; w = 5; h = 8; };
        panel.type = "bargauge";
        panel.fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.mode = "percentage";
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 80; color = "yellow"; }
            { value = 90; color = "red"; }
          ];
        };
        panel.options = {
          displayMode = "lcd";
          orientation = "horizontal";
        };
        influx.filter._measurement = "mikrotik-/ip/pool";
        influx.filter._field = ["total" "used"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> keep(columns: ["name", "total", "used"])
          |> group()
        '';
        panel.transformations = [{
          id = "rowsToFields";
          options.mappings = [
            { fieldName = "name"; handlerKey = "field.name"; }
            { fieldName = "total"; handlerKey = "max"; }
            { fieldName = "used"; handlerKey = "field.value"; }
          ];
        }];
      }
      {
        panel.title = "DHCP Leases";
        panel.gridPos = { x = 5; y = 16; w = 19; h = 19; };
        panel.type = "table";
        influx.imports = [
          "date"
          "internal/debug"
        ];
        influx.filter._measurement = "mikrotik-/ip/dhcp-server/lease";
        influx.filter._field = ["active-address" "status" "expires-after-ns" "active-server" "class-id"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> map(fn: (r) => ({r with
            "expires-at":
              if exists r["expires-after-ns"]
              then date.add(d:
                duration(v: (r["expires-after-ns"])),
                to: r._time
              )
              else debug.null(type: "time")
          }))
          |> filter(fn: (r) => r.status != "waiting")
          |> drop(columns: ["_start", "_stop", "_measurement", "host", "agent_host", "hostname", "expires-after-ns"])
          |> group()
        '';
      }
      {
        panel.title = "DHCP Leases by Server";
        panel.gridPos = { x = 0; y = 24; w = 5; h = 8; };
        panel.type = "bargauge";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.active-server}";
        };
        panel.options = {
          displayMode = "lcd";
          orientation = "horizontal";
        };
        influx.filter._measurement = "mikrotik-/ip/dhcp-server/lease";
        influx.filter._field = ["status" "active-server"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> filter(fn: (r) => r.status != "waiting")
          |> group(columns: ["_time", "active-server"])
          |> count(column: "status")
          |> group(columns: ["active-server"])
          |> last(column: "status")
        '';
      }

      {
        panel.title = "Network";
        panel.gridPos = { x = 0; y = 35; w = 24; h = 1; };
        panel.type = "row";
      }
      {
        panel.title = "Total Routes";
        panel.gridPos = { x = 0; y = 36; w = 2; h = 5; };
        panel.type = "gauge";
        influx.filter._measurement = "mikrotik-/routing/route";
        influx.filter._field = "active";
        influx.filter._value.values = [(lib.literalExpression "true")];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.groupBy = [
          {
            fields = ["_time"];
            fn = "count1";
          }
          {
            fields = [];
            fn = "last1";
          }
        ];
      }
      {
        panel.title = "Routes per Protocol";
        panel.gridPos = { x = 2; y = 36; w = 4; h = 5; };
        panel.type = "bargauge";
        panel.options = {
          displayMode = "lcd";
          orientation = "horizontal";
        };
        influx.filter._measurement = "mikrotik-/routing/route";
        influx.filter._field = "active";
        influx.filter._value.values = [(lib.literalExpression "true")];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.groupBy = [
          {
            fields = ["_time" "belongs-to"];
            fn = "count1";
          }
          {
            fields = ["belongs-to"];
            fn = "last1";
          }
        ];
      }
      {
        panel.title = "Ethernet Ports";
        panel.gridPos = { x = 6; y = 36; w = 6; h = 12; };
        panel.type = "table";
        influx.imports = ["strings" "contrib/bonitoo-io/hex"];
        influx.filter._measurement = "mikrotik-/interface/ethernet";
        # rate and full-duplex only exist for interfaces that are up
        influx.filter._field = ["rate" "full-duplex" "status"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> keep(columns: ["id", "name", "rate", "full-duplex"])
          |> group()
          |> map(fn: (r) => ({r with id: hex.uint(v: strings.trimLeft(v: r.id, cutset: "*"))}))
          |> sort(columns: ["id"])
          |> drop(columns: ["id"])
        '';
        fieldOrder = ["name" "rate" "full-duplex"];
        fields.rate = {
          unit = "bps";
          custom.width = 90;
        };
        fields.full-duplex = {
          custom.width = 90;
        };
      }
      {
        panel.title = "Interface Errors";
        panel.gridPos = { x = 12; y = 36; w = 12; h = 16; };
        panel.fieldConfig.defaults = {
          unit = "pps";
          custom.axisLabel = "packets in (-) / out (+) per second";
        };
        influx.filter._measurement = "snmp-interfaces";
        influx.filter._field = ["errors-in" "errors-out"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "derivative";

        fields.errors-in = {
          displayName = ''In ''${__field.labels.if-name}'';
          custom.transform = "negative-Y";
        };
        fields.errors-out.displayName = ''Out ''${__field.labels.if-name}'';
      }
      {
        panel.title = "POE";
        panel.gridPos = { x = 0; y = 48; w = 12; h = 4; };
        panel.type = "table";
        influx.imports = ["strings" "contrib/bonitoo-io/hex"];
        influx.filter._measurement = "mikrotik-/interface/ethernet";
        influx.filter._field = ["poe-out" "poe-priority"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> keep(columns: ["id", "name", "poe-out", "poe-priority"])
          |> group()
          |> map(fn: (r) => ({r with id: hex.uint(v: strings.trimLeft(v: r.id, cutset: "*"))}))
          |> sort(columns: ["id"])
          |> drop(columns: ["id"])
        '';
      }
      {
        panel.title = "Interface Traffic";
        panel.gridPos = { x = 0; y = 52; w = 24; h = 14; };
        panel.fieldConfig.defaults = {
          unit = "bps";
          custom.axisLabel = "bits in (-) / out (+) per second";
          custom.fillOpacity = 30;
        };
        panel.options.legend = {
          displayMode = "table";
          placement = "right";
          calcs = ["mean" "max" "min"];
        };
        influx.filter._measurement = "snmp-interfaces";
        influx.filter._field = ["bytes-in" "bytes-out"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "derivative";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: 8. * r._value}))
        '';

        fields.bytes-in = {
          displayName = ''In ''${__field.labels.if-name}'';
          custom.transform = "negative-Y";
        };
        fields.bytes-out.displayName = ''Out ''${__field.labels.if-name}'';
      }

      {
        panel.title = "Firewall";
        panel.gridPos = { x = 0; y = 66; w = 24; h = 1; };
        panel.type = "row";
      }
      {
        panel.title = "Open Connections";
        panel.gridPos = { x = 0; y = 67; w = 12; h = 8; };
        panel.type = "table";
        # TODO
      }
      {
        panel.title = "Open Connections Stats";
        panel.gridPos = { x = 12; y = 67; w = 12; h = 8; };
        panel.type = "barchart";
        # TODO
      }
      (firewallGraph "filter" {
        panel.title = "Logged Firewall Rules Traffic";
        panel.gridPos = { x = 0; y = 75; w = 12; h = 8; };
        influx.filter.log = "true";
      })
      (firewallGraph "nat" {
        panel.title = "Logged NAT Firewall Rules Traffic";
        panel.gridPos = { x = 12; y = 75; w = 12; h = 8; };
        influx.filter.log = "true";
      })
      (firewallGraph "filter" {
        panel.title = "Firewall Rules Traffic";
        panel.gridPos = { x = 0; y = 83; w = 12; h = 8; };
      })
      (firewallGraph "nat" {
        panel.title = "NAT Firewall Rules Traffic";
        panel.gridPos = { x = 12; y = 83; w = 12; h = 8; };
      })
    ];
  };
}
