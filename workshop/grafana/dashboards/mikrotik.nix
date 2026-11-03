{ config, pkgs, lib, ... }:
with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
let
  firewallModule = { config, ... }: {
    options.firewall.key = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    options.firewall.log = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    config = let
      inherit (config.firewall) key;
    in lib.mkIf (key != null) {
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "bps";
        displayName = "\${__field.labels.chain} | \${__field.labels.rule}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean" "max" "min"];
        legend.displayMode = "table";
        tooltip.sort = "desc";
      };
      greptime = let
        tags = [
          "chain"
          { name = "rule"; expression = "coalesce(comment, rule)"; }
        ];
        fields = [
          { name = "bytes"; expression = "bytes * 8"; }
        ];
        filter.log = lib.mkIf config.firewall.log "true";
      in [{
        table = ":ip:firewall:${key}";
        inherit tags fields filter;
        fn = "derivative";
      }] ++ lib.optional (key != "nat") {
        table = ":ipv6:firewall:${key}";
        inherit tags fields filter;
        fn = "derivative";
      };
    };
  };
  dashboardModule = {
    options.panels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        imports = [
          firewallModule
        ];
        options.greptime = lib.mkOption {
          type = let
            Query = lib.types.submodule {
              config.database = lib.mkDefault "mikrotik";
              config.filter.hostname = lib.mkDefault {
                op = "IN";
                values = [(lib.literalExpression "(\${hostname:sqlstring})")];
              };
            };
          in lib.types.either Query (lib.types.listOf Query);
        };
      }));
    };
  };
in {
  config.isz.grafana.dashboardsV2.mikrotik = { ... }: {
    imports = [
      dashboardModule
    ];
    title = "Mikrotik";
    spec.cursorSync = "Tooltip";
    variables.hostname = {
      spec.query = {
        datasource.name = "greptimedb";
        group = "info8cc-greptimedb-datasource";
        spec.editorType = "sql";
        spec.queryType = "table";
        spec.rawSql = ''
          SELECT DISTINCT
            hostname
          FROM
            mikrotik.":interface"
          WHERE
            $__timeFilter(greptime_timestamp)
          ORDER BY hostname ASC;
        '';
      };
      spec.label = "Host";
    };
    layout.kind = "RowsLayout";
    layout.spec.rows = [
      {
        spec.title = "System";
        spec.layout.kind = "GridLayout";
        spec.layout.spec.items = [
          { spec = {
              element.name = "identity";
              x = 0; y = 1; width = 2; height = 3;
            }; }
          { spec = {
              element.name = "routerboard-hw";
              x = 2; y = 1; width = 3; height = 2;
            }; }
          { spec = {
              element.name = "installed-packages";
              x = 5; y = 1; width = 5; height = 7;
            }; }
          { spec = {
              element.name = "memory-bargauge";
              x = 10; y = 1; width = 4; height = 7;
            }; }
          { spec = {
              element.name = "cpu-load";
              x = 14; y = 1; width = 5; height = 7;
            }; }
          { spec = {
              element.name = "cpu-frequency";
              x = 19; y = 1; width = 5; height = 7;
            }; }
          { spec = {
              element.name = "cpu";
              x = 2; y = 3; width = 3; height = 2;
            }; }
          { spec = {
              element.name = "temperature";
              x = 0; y = 4; width = 2; height = 6;
            }; }
          { spec = {
              element.name = "system-version";
              x = 2; y = 5; width = 3; height = 3;
            }; }
          { spec = {
              element.name = "uptime";
              x = 2; y = 8; width = 3; height = 2;
            }; }
          { spec = {
              element.name = "active-users";
              x = 5; y = 8; width = 9; height = 7;
            }; }
          { spec = {
              element.name = "memory-utilization";
              x = 14; y = 9; width = 10; height = 7;
            }; }
          { spec = {
              element.name = "voltage";
              x = 0; y = 10; width = 2; height = 2;
            }; }
          { spec = {
              element.name = "ip-address";
              x = 2; y = 10; width = 3; height = 2;
            }; }
          { spec = {
              element.name = "public-address";
              x = 0; y = 12; width = 5; height = 3;
            }; }
        ];
      }
      {
        spec.title = "DHCP";
        spec.layout.kind = "GridLayout";
        spec.layout.spec.items = [
          { spec = {
              element.name = "dhcp-pool-usage";
              x = 0; y = 16; width = 5; height = 8;
            }; }
          { spec = {
              element.name = "dhcp-leases";
              x = 5; y = 16; width = 19; height = 19;
            }; }
          { spec = {
              element.name = "dhcp-leases-by-server";
              x = 0; y = 24; width = 5; height = 8;
            }; }
        ];
      }
      {
        spec.title = "Network";
        spec.layout.kind = "GridLayout";
        spec.layout.spec.items = [
          { spec = {
              element.name = "network-routes";
              x = 0; y = 36; width = 2; height = 5;
            }; }
          { spec = {
              element.name = "network-routes-per-protocol";
              x = 2; y = 36; width = 4; height = 5;
            }; }
          { spec = {
              element.name = "network-ethernet-ports";
              x = 6; y = 36; width = 6; height = 12;
            }; }
          { spec = {
              element.name = "network-interface-errors";
              x = 12; y = 36; width = 12; height = 16;
            }; }
          { spec = {
              element.name = "network-poe";
              x = 0; y = 48; width = 12; height = 4;
            }; }
          { spec = {
              element.name = "network-interface-traffic";
              x = 0; y = 52; width = 24; height = 14;
            }; }
        ];
      }
      {
        spec.title = "Firewall";
        spec.layout.kind = "GridLayout";
        spec.layout.spec.items = [
          { spec = {
              element.name = "firewall-open-connections";
              x = 0; y = 67; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "firewall-open-connections-stats";
              x = 12; y = 67; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "firewall-logged-filter";
              x = 0; y = 75; width = 12; height = 12;
            }; }
          { spec = {
              element.name = "firewall-logged-nat";
              x = 12; y = 75; width = 12; height = 12;
            }; }
          { spec = {
              element.name = "firewall-filter";
              x = 0; y = 87; width = 12; height = 14;
            }; }
          { spec = {
              element.name = "firewall-nat";
              x = 12; y = 87; width = 12; height = 14;
            }; }
        ];
      }
      {
        spec.title = "Netwatch";
        spec.layout.kind = "GridLayout";
        spec.layout.spec.items = [
          { spec = {
              element.name = "netwatch-status";
              x = 0; y = 102; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "netwatch-info";
              x = 12; y = 102; width = 12; height = 8;
            }; }
        ];
      }
      {
        spec.title = "Wireless";
        spec.layout.kind = "GridLayout";
        spec.layout.spec.items = [
          { spec = {
              element.name = "wireless-noise-floor";
              x = 0; y = 111; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "wireless-ccq";
              x = 12; y = 111; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "wireless-client-devices";
              x = 0; y = 119; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "wireless-client-count";
              x = 12; y = 119; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "wireless-client-ccq";
              x = 0; y = 127; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "wireless-client-traffic";
              x = 12; y = 127; width = 12; height = 8;
            }; }
          { spec = {
              element.name = "wireless-client-rssi";
              x = 0; y = 135; width = 12; height = 7;
            }; }
          { spec = {
              element.name = "wireless-client-snr";
              x = 12; y = 135; width = 12; height = 7;
            }; }

        ];
      }
    ];
    panels.identity = {
      spec.title = "Identity";
      spec.vizConfig.group = "stat";
      # TODO
    };
    panels.routerboard-hw = {
      spec.title = "Routerboard HW";
      spec.vizConfig.group = "stat";
      greptime.table = ":system:resource";
      greptime.fields = [ "board-name" ];
      greptime.fn = "last1";
      spec.vizConfig.spec.options.reduceOptions.fields = "/.*/";
    };
    panels.installed-packages = {
      spec.title = "Installed Packages";
      spec.vizConfig.group = "table";
      # TODO
    };
    panels.memory-bargauge = {
      spec.vizConfig.group = "bargauge";
      spec.vizConfig.spec.fieldConfig.defaults = {
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
      spec.vizConfig.spec.options = {
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
    };
    panels.cpu-load = {
      spec.title = "CPU Load";
      influx.filter._measurement = "snmp";
      influx.filter._field = "cpu-load";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "mean";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "percent";
      };
    };
    panels.cpu-frequency = {
      spec.title = "CPU Frequency";
      influx.filter._measurement = "snmp";
      influx.filter._field = "cpu-frequency";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "mean";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "MHz";
      };
    };
    panels.cpu = {
      spec.title = "CPU";
      spec.vizConfig.group = "stat";
      greptime.table = ":system:resource";
      greptime.tags = [ "cpu" ];
      greptime.fields = [ "cpu-frequency" ];
      greptime.fn = "last1";
      spec.vizConfig.spec.options.textMode = "value_and_name";
      spec.vizConfig.spec.fieldConfig.defaults.unit = "MHz";
      spec.vizConfig.spec.fieldConfig.defaults.displayName = "\${__field.labels.cpu}";
    };
    panels.temperature = {
      spec.title = "Temperature";
      spec.vizConfig.group = "gauge";
      influx.filter._measurement = "snmp-mikrotik-gauges";
      influx.filter.unit = "celsius";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "last1";
      influx.groupBy = {
        fields = [];
        fn = "max1";
      };
      spec.vizConfig.spec.fieldConfig.defaults = {
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
    };
    panels.system-version = {
      spec.title = "System version";
      spec.vizConfig.group = "stat";
      greptime.table = ":system:resource";
      greptime.fields = [ "version" ];
      greptime.fn = "last1";
      spec.vizConfig.spec.options.reduceOptions.fields = "/.*/";
    };
    panels.uptime = {
      spec.title = "Uptime";
      spec.vizConfig.group = "stat";
      influx.filter._measurement = "snmp";
      influx.filter._field = "uptime";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "last1";
      influx.extra = ''
        |> map(fn: (r) => ({r with _value: float(v: r._value)/100.0}))
      '';
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "dtdurations";
      };
    };
    panels.active-users = {
      spec.title = "Active Users";
      spec.vizConfig.group = "table";
      # TODO
    };
    panels.memory-utilization = {
      spec.title = "Memory Utilization";
      spec.vizConfig.spec.fieldConfig.defaults = {
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
    };
    panels.voltage = {
      spec.title = "Voltage";
      spec.vizConfig.group = "stat";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "volt";
      };
      influx.filter._measurement = "snmp";
      influx.filter._field = "voltage";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "last1";
    };
    panels.ip-address = {
      spec.title = "IP Address";
      spec.vizConfig.group = "stat";
      spec.vizConfig.spec.fieldConfig.defaults = {
        displayName = "\${__field.labels.interface}";
      };
      spec.vizConfig.spec.options.reduceOptions.fields = "/.*/";
      greptime.table = ":ip:address";
      greptime.tags = ["interface"];
      greptime.fields = ["address"];
      greptime.filter.disabled = "false";
      greptime.fn = "last1";
    };
    panels.public-address = {
      spec.title = "Public Address";
      spec.vizConfig.group = "stat";
      spec.vizConfig.spec.fieldConfig.defaults = {
        displayName = "\${__field.labels.interface}";
      };
      spec.vizConfig.spec.options.reduceOptions.fields = "/.*/";
      greptime.table = ":ip:address";
      greptime.tags = ["interface"];
      greptime.fields = ["address"];
      greptime.filter.disabled = "false";
      greptime.fn = "last1";
    };

    # DHCP
    panels.dhcp-pool-usage = {
      spec.title = "IP Pool Usage";
      spec.vizConfig.group = "bargauge";
      spec.vizConfig.spec.fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "percentage";
        thresholds.steps = [
          { value = null; color = "green"; }
          { value = 80; color = "yellow"; }
          { value = 90; color = "red"; }
        ];
      };
      spec.vizConfig.spec.options = {
        displayMode = "lcd";
        orientation = "horizontal";
      };
      greptime.queryType = "table";
      greptime.table = ":ip:pool";
      greptime.tags = ["name"];
      greptime.fields = ["total" "used"];
      greptime.fn = "last1";
      spec.data.spec.transformations = [{
        group = "rowsToFields";
        spec.options.mappings = [
          { fieldName = "greptime_timestamp"; handlerKey = "__ignore"; }
          { fieldName = "name"; handlerKey = "field.name"; }
          { fieldName = "total"; handlerKey = "max"; }
          { fieldName = "used"; handlerKey = "field.value"; }
        ];
      }];
    };
    panels.dhcp-leases = {
      spec.title = "DHCP Leases";
      spec.vizConfig.group = "table";
      greptime.queryType = "table";
      greptime.table = ":ip:dhcp-server:lease";
      greptime.tags = ["agent_host" "blocked" "comment" "disabled" "dynamic" "host" "hostname" "mac-address" "address" "server" "client-id" "id" "dhcp-option"];
      greptime.fields = [
        "active-address" "status"
        { expression = ''greptime_timestamp + arrow_cast("expires-after-ns", 'Duration(ns)')''; name = "expires-at"; }
        "active-server" "class-id"
      ];
      greptime.fn = "last1";
      greptime.filter.status = {
        op = "!=";
        values = ["waiting"];
      };
    };
    panels.dhcp-leases-by-server = {
      spec.title = "DHCP Leases by Server";
      spec.vizConfig.group = "bargauge";
      spec.vizConfig.spec.options = {
        displayMode = "lcd";
        orientation = "horizontal";
        reduceOptions.values = true;
      };
      greptime.rawSql = ''
        WITH timestamps AS (
          SELECT
            hostname,
            MAX(greptime_timestamp) AS greptime_timestamp
          FROM
            mikrotik.":ip:dhcp-server:lease"
          WHERE
            $__timeFilter(greptime_timestamp)
            AND hostname IN (''${hostname:sqlstring})
          GROUP BY
            hostname
        )
        SELECT
          "active-server",
          "status",
          COUNT(DISTINCT "mac-address") AS count
        FROM
          timestamps
          INNER JOIN mikrotik.":ip:dhcp-server:lease" USING (greptime_timestamp, hostname)
        WHERE
          status != 'waiting'
        GROUP BY hostname, "active-server", "status"
      '';
    };

    # Network
    panels.network-routes = {
      spec.title = "Total Routes";
      spec.vizConfig.group = "gauge";
      greptime.rawSql = ''
        WITH timestamps AS (
          SELECT
            hostname,
            MAX(greptime_timestamp) AS greptime_timestamp
          FROM
            mikrotik.":routing:route"
          WHERE
            $__timeFilter(greptime_timestamp)
            AND hostname IN (''${hostname:sqlstring})
          GROUP BY
            hostname
        )
        SELECT
          COUNT(*) AS count
        FROM
          timestamps
          INNER JOIN mikrotik.":routing:route" USING (greptime_timestamp, hostname)
        WHERE
          active
        GROUP BY hostname
      '';
    };
    panels.network-routes-per-protocol = {
      spec.title = "Routes per Protocol";
      spec.vizConfig.group = "bargauge";
      spec.vizConfig.spec.options = {
        displayMode = "lcd";
        orientation = "horizontal";
        reduceOptions.values = true;
      };
      greptime.rawSql = ''
        WITH timestamps AS (
          SELECT
            hostname,
            MAX(greptime_timestamp) AS greptime_timestamp
          FROM
            mikrotik.":routing:route"
          WHERE
            $__timeFilter(greptime_timestamp)
            AND hostname IN (''${hostname:sqlstring})
          GROUP BY
            hostname
        )
        SELECT
          "belongs-to",
          COUNT(*) AS count
        FROM
          timestamps
          INNER JOIN mikrotik.":routing:route" USING (greptime_timestamp, hostname)
        WHERE
          active
        GROUP BY hostname, "belongs-to"
      '';
    };
    panels.network-ethernet-ports = {
      spec.title = "Ethernet Ports";
      spec.vizConfig.group = "table";
      greptime.rawSql = ''
        WITH timestamps AS (
          SELECT
            hostname,
            MAX(greptime_timestamp) AS greptime_timestamp
          FROM
            mikrotik.":interface:ethernet"
          WHERE
            $__timeFilter(greptime_timestamp)
            AND hostname IN (''${hostname:sqlstring})
          GROUP BY
            hostname
        )
        SELECT
          name,
          rate,
          "full-duplex"
        FROM
          timestamps
        INNER JOIN mikrotik.":interface:ethernet"
          USING (greptime_timestamp, hostname)
        WHERE
          status IS NOT NULL
        ORDER BY lpad(ltrim(id, '*'), 8, '0')
      '';
      fieldOrder = ["name" "rate" "full-duplex"];
      fields.rate = {
        unit = "bps";
        custom.width = 90;
      };
      fields.full-duplex = {
        custom.width = 90;
      };
    };
    panels.network-interface-errors = {
      spec.title = "Interface Errors";
      spec.vizConfig.spec.fieldConfig.defaults = {
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
    };
    panels.network-poe = {
      spec.title = "POE";
      spec.vizConfig.group = "table";
      greptime.rawSql = ''
        WITH timestamps AS (
          SELECT
            hostname,
            MAX(greptime_timestamp) AS greptime_timestamp
          FROM
            mikrotik.":interface:ethernet"
          WHERE
            $__timeFilter(greptime_timestamp)
            AND hostname IN (''${hostname:sqlstring})
          GROUP BY
            hostname
        )
        SELECT
          name,
          "poe-out",
          "poe-priority"
        FROM
          timestamps
        INNER JOIN mikrotik.":interface:ethernet"
          USING (greptime_timestamp, hostname)
        WHERE
          status IS NOT NULL
        ORDER BY lpad(ltrim(id, '*'), 8, '0')
      '';
    };
    panels.network-interface-traffic = {
      spec.title = "Interface Traffic";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "bps";
        custom.axisLabel = "bits in (-) / out (+) per second";
        custom.fillOpacity = 30;
      };
      spec.vizConfig.spec.options.legend = {
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
    };

    # Firewall
    panels.firewall-open-connections = {
      spec.title = "Open Connections";
      spec.vizConfig.group = "table";
      # TODO
    };
    panels.firewall-open-connections-stats = {
      spec.title = "Open Connections Stats";
      spec.vizConfig.group = "barchart";
      # TODO
    };
    panels.firewall-logged-filter = {
      firewall.key = "filter";
      firewall.log = true;
      spec.title = "Logged Firewall Rules Traffic";
    };
    panels.firewall-logged-nat = {
      firewall.key = "nat";
      firewall.log = true;
      spec.title = "Logged NAT Firewall Rules Traffic";
    };
    panels.firewall-filter = {
      firewall.key = "filter";
      spec.title = "Firewall Rules Traffic";
    };
    panels.firewall-nat = {
      firewall.key = "nat";
      spec.title = "NAT Firewall Rules Traffic";
    };

    # Netwatch
    panels.netwatch-status = {
      spec.title = "Status over time";
      spec.vizConfig.group = "state-timeline";
      # TODO
    };
    panels.netwatch-info = {
      spec.title = "Netwatch Info";
      spec.vizConfig.group = "table";
      # TODO
    };

    # Wireless
    panels.wireless-noise-floor = {
      spec.title = "Noise Floor";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "dBm";
        displayName = "\${__field.labels.channel-name}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean" "lastNotNull" "max" "min"];
        legend.displayMode = "table";
      };
      greptime.table = ":interface:wireless";
      greptime.tags = ["hostname" "channel-name"];
      greptime.fields = ["noise-floor"];
      greptime.fn = "mean";
      greptime.filter.noise-floor = { op = "!="; values = [null]; };
    };
    panels.wireless-ccq = {
      spec.title = "Overall TX CCQ";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "percent";
        displayName = "\${__field.labels.channel-name}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean" "lastNotNull" "max" "min"];
        legend.displayMode = "table";
      };
      greptime.table = ":interface:wireless";
      greptime.tags = ["hostname" "channel-name"];
      greptime.fields = ["overall-tx-ccq"];
      greptime.fn = "mean";
      greptime.filter.noise-floor = { op = "!="; values = [null]; };
    };
    panels.wireless-client-devices = {
      spec.title = "Client Devices";
      spec.vizConfig.group = "table";
      influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
      influx.filter._field = [
        "tx-rate-name"
        "rx-rate-name"
        "uptime-ns"
      ];
      influx.filter.hostname = "\${hostname}";
      influx.fn = "last1";
      influx.pivot = true;
      influx.extra = ''
        |> drop(columns: ["_measurement", "host", "hostname", "agent_host"])
        |> group()
      '';
      fieldOrder = [
        "_time"
        "last-ip"
        "mac-address"
        "rx-rate-name"
        "tx-rate-name"
        "uptime-ns"
        "interface"
      ];
      fields.uptime-ns = {
        unit = "ns";
      };
    };
    panels.wireless-client-count = {
      spec.title = "Number of clients";
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean" "lastNotNull" "max" "min"];
        legend.displayMode = "table";
      };
      influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
      influx.filter._field = "uptime-ns";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "mean";
      influx.groupBy = [
        {
          fields = ["_time" "interface"];
          fn = "count";
        }
        {
          fields = ["interface"];
          fn = "mean";
        }
      ];
    };
    panels.wireless-client-ccq = {
      spec.title = "WLAN Clients Tx CCQ";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "percent";
        displayName = "\${__field.labels.interface} \${__field.labels.mac-address}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean"];
        legend.displayMode = "table";
        legend.placement = "right";
      };
      influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
      influx.filter._field = "tx-ccq";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "mean";
    };
    panels.wireless-client-traffic = {
      spec.title = "Clients Traffic";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "bps";
        displayName = "\${__field.labels.interface} \${__field.labels.mac-address}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = [];
        legend.displayMode = "table";
        legend.placement = "right";
      };
      influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
      influx.filter._field = ["tx-bytes" "rx-bytes"];
      influx.filter.hostname = "\${hostname}";
      influx.fn = "derivative";
      fields.tx-bytes = {
        custom.transform = "negative-Y";
      };
    };
    panels.wireless-client-rssi = {
      spec.title = "Clients Signal Strength";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "dBm";
        displayName = "\${__field.labels.interface} \${__field.labels.mac-address}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean"];
        legend.displayMode = "table";
        legend.placement = "right";
      };
      influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
      influx.filter._field = "signal-strength";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "mean";
    };
    panels.wireless-client-snr = {
      spec.title = "Clients Signal-to-Noise";
      spec.vizConfig.spec.fieldConfig.defaults = {
        unit = "dBm";
        displayName = "\${__field.labels.interface} \${__field.labels.mac-address}";
      };
      spec.vizConfig.spec.options = {
        legend.calcs = ["mean"];
        legend.displayMode = "table";
        legend.placement = "right";
      };
      influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
      influx.filter._field = "signal-to-noise";
      influx.filter.hostname = "\${hostname}";
      influx.fn = "mean";
    };
  };
}
