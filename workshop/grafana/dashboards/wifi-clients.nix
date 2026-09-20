{ config, options, pkgs, lib, ... }:
{
  config.isz.grafana.dashboardsV2.vQ9bVarMz = {
    title = "WiFi Clients";
    tags = [ "home" "wifi" ];
    defaultDatasourceName = "greptimedb";
    layout.kind = "GridLayout";
    layout.spec.items = [
      { spec = {
          element.name = "clients-table";
          x = 0; y = 0; width = 24; height = 20;
        }; }
      { spec = {
          element.name = "tx-rate";
          x = 0; y = 20; width = 12; height = 11;
        }; }
      { spec = {
          element.name = "throughput";
          x = 12; y = 20; width = 12; height = 11;
        }; }
      { spec = {
          element.name = "logs";
          x = 0; y = 31; width = 24; height = 8;
        }; }
    ];
    panels = let
      interval = config.isz.telegraf.interval.mikrotik;
      leasesQuery = ''
        SELECT
          hostname,
          "mac-address",
          last_value(comment ORDER BY greptime_timestamp DESC) AS comment,
          last_value("active-address" ORDER BY greptime_timestamp DESC) AS "active-address",
        FROM mikrotik.":ip:dhcp-server:lease"
        WHERE $__timeFilter(greptime_timestamp)
        GROUP BY hostname, "mac-address"
      '';
    in {
      clients-table = {
        spec.title = "WiFi Clients";
        spec.vizConfig.group = "table";
        spec.vizConfig.spec.fieldConfig.defaults = {
          custom.filterable = true;
        };
        greptime = {
          queryType = "table";
          rawSql = ''
            WITH
              interfaces_raw AS (
                SELECT DISTINCT ON (hostname, name)
                  hostname,
                  name,
                  ssid,
                  band,
                  "master-interface"
                FROM mikrotik.":interface:wireless"
                WHERE $__timeFilter(greptime_timestamp)
                ORDER BY hostname, name, greptime_timestamp DESC
              ),
              interfaces AS (
                SELECT
                  i.hostname,
                  i.name,
                  i.ssid,
                  coalesce(i.band, m.band) AS band
                FROM interfaces_raw i
                LEFT JOIN interfaces_raw m ON m.name = i."master-interface"
              ),
              leases AS (
                ${leasesQuery}
              ),
              registrations AS (
                SELECT
                  hostname,
                  interface,
                  "mac-address",
                  max(greptime_timestamp) AS "last-seen",
                  last_value("last-ip" ORDER BY greptime_timestamp DESC) AS "last-ip",
                  last_value("tx-rate-name" ORDER BY greptime_timestamp DESC) AS "tx-rate",
                  last_value("rx-rate-name" ORDER BY greptime_timestamp DESC) AS "rx-rate",
                  last_value("uptime-ns" ORDER BY greptime_timestamp DESC) AS "uptime",
                  last_value("signal-strength" ORDER BY greptime_timestamp DESC) AS "signal-strength",
                  last_value("tx-ccq" ORDER BY greptime_timestamp DESC) AS "tx-ccq",
                FROM mikrotik.":interface:wireless:registration-table"
                WHERE
                  $__timeFilter(greptime_timestamp)
                  AND rate IS NULL
                GROUP BY hostname, interface, "mac-address"
                ORDER BY hostname, interface, "last-seen" DESC
              )
            SELECT
              r.interface,
              i.band,
              i.ssid,
              r."last-seen",
              r."mac-address",
              r."last-ip",
              l."active-address",
              (l.comment IS NOT NULL) AS known,
              l.comment,
              r."rx-rate",
              r."tx-rate",
              r."tx-ccq",
              r."uptime",
              r."signal-strength",
            FROM
              registrations r
            LEFT JOIN leases l USING (hostname, "mac-address")
            LEFT JOIN interfaces i ON i.hostname == r.hostname AND i.name == r.interface
            ORDER BY r.hostname, interface, "last-seen" DESC, comment, "mac-address"
          '';
        };
        fields.last-seen.custom.width = 170;
        fields.interface.custom.width = 65;
        fields.band.custom.width = 100;
        fields.ssid.custom.width = 170;
        fields.mac-address = {
          custom.width = 150;
          links = [{
            url = ''/d/eXssGz84k/wifi-client?orgId=1&var-macaddress=''${__value.text}'';
          }];
        };
        fields.comment.custom.width = 294;
        fields.known = {
          custom.cellOptions = {
            mode = "basic";
            type = "color-background";
          };
          custom.width = 59;
        };
        fields.active-address.custom.width = 120;
        fields.signal-strength = {
          unit = "dBm";
          custom.width = 90;
        };
        fields.tx-ccq = {
          custom.width = 75;
          unit = "percent";
          color.mode = "thresholds";
          thresholds.mode = "absolute";
          thresholds.steps = [
            { value = null; color = "red"; }
            { value = 50; color = "#EAB839"; }
            { value = 90; color = "green"; }
          ];
          custom.cellOptions.type = "color-text";
        };
        fields.last-ip.custom.width = 120;
        fields.uptime = {
          unit = "ns";
          custom.width = 80;
        };
        fields.encryption.custom.width = 81;
        fieldOrder = [
          "last-seen"
          "interface"
          "band"
          "ssid"
          "mac-address"
          "comment"
          "known"
          "active-address"
          "signal-strength"
          "tx-ccq"
          "last-ip"
          "uptime"
          "tx-rate"
          "rx-rate"
        ];
      };
      tx-rate = {
        spec.title = "TX Rate";
        spec.data.spec.queryOptions.interval = interval;
        spec.vizConfig.spec.options = {
          tooltip.mode = "multi";
          tooltip.sort = "desc";
          legend.showLegend = false;
        };
        spec.vizConfig.spec.fieldConfig.defaults = {
          displayName = ''''${__field.labels.interface} ''${__field.labels.mac-address} ''${__field.labels.comment}'';
          unit = "bps";
          links = [{
            title = "Show details";
            url = ''/d/eXssGz84k/wifi-client?orgId=1&var-macaddress=''${__field.labels.mac-address}'';
          }];
        };
        greptime.rawSql = ''
          WITH
            leases AS (${leasesQuery}),
            rates AS (
              SELECT
                hostname,
                interface,
                "mac-address",
                greptime_timestamp AS "time",
                mean("tx-rate") RANGE '$__interval' AS "tx-rate",
              FROM
                mikrotik.":interface:wireless:registration-table"
              WHERE
                $__timeFilter(greptime_timestamp)
                AND rate IS NULL
              ALIGN '$__interval' BY (hostname, interface, "mac-address")
              ORDER BY time ASC
            )
          SELECT
            hostname,
            interface,
            "mac-address",
            comment,
            "time",
            "tx-rate"
          FROM rates
          LEFT JOIN leases USING (hostname, "mac-address")
        '';
      };
      throughput = {
        spec.title = "Throughput";
        spec.data.spec.queryOptions.interval = interval;
        spec.vizConfig.spec.options = {
          tooltip.mode = "multi";
          tooltip.sort = "desc";
          legend.showLegend = false;
        };
        spec.vizConfig.spec.fieldConfig.defaults = {
          displayName = ''''${__field.name} ''${__field.labels.interface} ''${__field.labels.comment}'';
          unit = "Bps";
          custom.axisLabel = "in (-) / out (+)";
          custom.scaleDistribution.type = "symlog";
          custom.scaleDistribution.log = 10;
          links = [{
            title = "Show details";
            url = ''/d/eXssGz84k/wifi-client?orgId=1&var-macaddress=''${__field.labels.mac-address}'';
          }];
        };
        fields.rx-bytes.custom.transform = "negative-Y";
        greptime.rawSql = ''
          WITH
            leases AS (${leasesQuery}),
            rates AS (
              SELECT DISTINCT ON (hostname, interface, "mac-address", date_bin(interval '$__interval', greptime_timestamp))
                hostname,
                interface,
                "mac-address",
                greptime_timestamp AS "time",
                "tx-bytes",
                "rx-bytes",
              FROM
                mikrotik.":interface:wireless:registration-table"
              WHERE
                $__timeFilter(greptime_timestamp)
                AND rate IS NULL
              ORDER BY hostname, interface, "mac-address", date_bin(interval '$__interval', greptime_timestamp), greptime_timestamp DESC
            ),
            rates2 AS (
              SELECT
                hostname,
                interface,
                "mac-address",
                time,
                time - lag("time") over (partition by hostname, interface, "mac-address" order by time) AS delta_time,
                "tx-bytes" - lag("tx-bytes") over (partition by hostname, interface, "mac-address" order by time) AS "delta_tx-bytes",
                "rx-bytes" - lag("rx-bytes") over (partition by hostname, interface, "mac-address" order by time) AS "delta_rx-bytes",
              FROM rates
            )
          SELECT
            hostname,
            interface,
            "mac-address",
            "comment",
            "time",
            CASE WHEN "delta_tx-bytes" < 0 THEN NULL ELSE "delta_tx-bytes" / arrow_cast(delta_time, 'Float64')*1e9 END AS "tx-bytes",
            CASE WHEN "delta_rx-bytes" < 0 THEN NULL ELSE "delta_rx-bytes" / arrow_cast(delta_time, 'Float64')*1e9 END AS "rx-bytes",
          FROM rates2
          LEFT JOIN leases USING (hostname, "mac-address")
        '';
      };
      logs = {
        datasourceName = "loki";
        spec.title = "Recent Logs";
        spec.vizConfig.group = "logs";
        spec.data.spec.queries = [{
          spec.query.spec.expr = ''
            {source_type="mikrotik", topic="wireless"}
            | json message="message"
            | regexp `(?P<macaddress>(?:[0-9A-F]{2}:){5}[0-9A-F]{2})`
            | line_format `{{if .name}}{{.name}}{{else}}{{.topic}}{{if and (ne .subtopic "<null>") (ne .subtopic "")}},{{.subtopic}}{{end}}{{end}} {{or .message __line__}}`
            | drop message,detected_level,service_name,subtopic="<null>",timestamp_end,__error__,__error_details__
          '';
          spec.query.spec.queryType = "range";
        }];
        spec.vizConfig.spec.options.showTime = true;
      };
    };
  };
  config.isz.grafana.dashboardsV2.eXssGz84k = {
    title = "WiFi Client";
    defaultDatasourceName = "workshop";
    variables = {
      macaddress = {
        influx.query = ''
          import "join"
          import "influxdata/influxdb/schema"

          tags = schema.tagValues(
            bucket: v.defaultBucket,
            tag: "mac-address",
            predicate: (r) => r._measurement == "mikrotik-/interface/wireless/registration-table",
            start: v.timeRangeStart,
            stop: v.timeRangeStop
          )
          |> map (fn: (r) => ({"mac-address": r._value}))

          leases = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/ip/dhcp-server/lease")
            |> filter(fn: (r) => r._field == "status")
            |> filter(fn: (r) => exists r["mac-address"])
            |> last()
            |> group(columns: ["mac-address"])
            |> sort(columns: ["_time"])
            |> last(column: "_value")
            |> group()
            |> keep(columns: ["mac-address", "comment"])

          join.left(
            left: tags, right: leases,
            on: (l, r) => l["mac-address"] == r["mac-address"],
            as: (l, r) => ({noComment: not exists r.comment, comment: r.comment, _value: l["mac-address"] + (if exists r["comment"] then " - "+r["comment"] else "")})
          )
          |> sort(columns: ["noComment", "comment", "_value"])
          '';
        spec.label = "MAC address";
        spec.regex = ''/^(?<text>(?<value>[^ ]+).*)/'';
        spec.includeAll = false;
      };
    };
    annotations = [{
      spec.enable = true;
      spec.name = "Wireless logs";
      spec.query = {
        datasource.name = config.isz.grafana.datasources.loki.uid;
        group = config.isz.grafana.datasources.loki.type;
      };
      spec.legacyOptions = {
        expr = ''
          {source_type="mikrotik",topic="wireless",level!="debug"} |~ `(?i)''${macaddress}` | json | line_format `{{or .message __line__}}`
        '';
        tagKeys = "host,level";
      };
    }];
    links = [
      {
        tags = ["wifi"];
        type = "dashboards";
      }
    ];
    layout.kind = "GridLayout";
    layout.spec.items = [
      { spec = {
          element.name = "lease-info";
          x = 0; y = 0; width = 20; height = 3;
        }; }
      { spec = {
          element.name = "wireless-rate";
          x = 0; y = 3; width = 10; height = 8;
        }; }
      { spec = {
          element.name = "throughput";
          x = 10; y = 3; width = 10; height = 8;
        }; }
      { spec = {
          element.name = "rssi-at-rate";
          x = 0; y = 11; width = 10; height = 8;
        }; }
      { spec = {
          element.name = "tx-ccq";
          x = 10; y = 11; width = 10; height = 8;
        }; }
      { spec = {
          element.name = "outgoing-traffic";
          x = 0; y = 19; width = 10; height = 8;
        }; }
      { spec = {
          element.name = "logs";
          x = 0; y = 27; width = 20; height = 8;
        }; }
      { spec = {
          element.name = "stats";
          x = 20; y = 0; width = 4; height = 36;
        }; }
    ];
    panels = let
      interval = config.isz.telegraf.interval.mikrotik;
      nfInterval = config.isz.telegraf.interval.netflow;
    in {
      lease-info = {
        spec.title = "";
        spec.vizConfig.group = "table";
        influx.filter._measurement = "mikrotik-/ip/dhcp-server/lease";
        influx.filter.mac-address = "\${macaddress}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> last(column: "_time")
          |> drop(columns: ["hostname", "host", "agent_host", "mac-address"])
          |> group(columns: ["_measurement"])
        '';
        fields.comment.custom.width = 200;
        fields._time.custom.width = 160;
        fields.status.custom.width = 75;
        fields.active-address.custom.width = 125;
        fields.address.custom.width = 125;
        fields.blocked.custom.width = 75;
        fields.disabled.custom.width = 75;
        fields.dynamic.custom.width = 75;
        fields.radius.custom.width = 75;
        fields.expires-after-ns.unit = "ns";
        fields.last-seen-ns.unit = "ns";
        fieldOrder = [
          "comment"
          "_time"
          "status"
          "active-address"
          "last-seen-ns"
          "expires-after-ns"
          "host-name"
          "active-client-id"
        ];
      };
      wireless-rate = {
        spec.title = "Wireless Rate";
        spec.vizConfig.spec.options.tooltip.mode = "multi";
        spec.data.spec.queryOptions.interval = interval;
        spec.vizConfig.spec.fieldConfig.defaults = {
          custom.axisLabel = "rx (-) / tx (+)";
          unit = "bps";
          displayName = "\${__field.labels.interface} \${__field.labels.mac-address}";
        };
        fields.rx-rate.custom.transform = "negative-Y";
        influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
        influx.filter._field = ["tx-rate" "rx-rate"];
        influx.filter.mac-address = "\${macaddress}";
        influx.fn = "mean";
        influx.createEmpty = true;
      };
      throughput = {
        spec.title = "Throughput";
        spec.vizConfig.spec.options.tooltip.mode = "multi";
        spec.data.spec.queryOptions.interval = interval;
        spec.vizConfig.spec.fieldConfig.defaults = {
          custom.axisLabel = "in (-) / out (+)";
          custom.fillOpacity = 10;
          custom.scaleDistribution = {
            type = "symlog";
            linearThreshold = 10;
            log = 10;
          };
          unit = "Bps";
          displayName = "\${__field.labels.interface} \${__field.labels.mac-address}";
        };
        fields.rx-bytes.custom.transform = "negative-Y";
        influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
        influx.filter._field = ["tx-bytes" "rx-bytes"];
        influx.filter.mac-address = "\${macaddress}";
        influx.fn = "derivative";
        influx.createEmpty = true;
      };
      rssi-at-rate = {
        spec.title = "Signal Strength at Rate";
        spec.vizConfig.spec.options.tooltip.mode = "multi";
        spec.data.spec.queryOptions.interval = interval;
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "dBm";
          displayName = "\${__field.labels.rate}";
        };
        influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
        influx.filter._field = ["strength-at-rates" "strength-at-rates-age-ns"];
        influx.filter.mac-address = "\${macaddress}";
        influx.fn = "mean";
        influx.pivot = true;
        influx.imports = ["date"];
        influx.extra = ''
          |> map(fn: (r) => ({
            _value: r["strength-at-rates"],
            _field: "strength-at-rates",
            rate: r.rate,
            _time:
              if exists r["strength-at-rates-age-ns"]
              then date.sub(
                from: r._time,
                d: duration(v: int(v: r["strength-at-rates-age-ns"]))
              )
              else r._time
          }))
          |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: true)
        '';
      };
      tx-ccq = {
        spec.title = "TX CCQ";
        spec.data.spec.queryOptions.interval = interval;
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "percent";
        };
        influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
        influx.filter._field = ["tx-ccq"];
        influx.filter.mac-address = "\${macaddress}";
        influx.fn = "mean";
        influx.createEmpty = true;
      };
      outgoing-traffic = {
        spec.title = "Outgoing traffic";
        spec.data.spec.queryOptions.interval = nfInterval;
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "Bps";
        };
        influx = {
          bucket = "netflow";
          imports = ["strings"];
          filter._measurement = "netflow_ip_outgoing";
          filter._field = "in_bytes";
          filter.in_src_mac.values = [(lib.literalExpression "strings.toLower(v: \${macaddress:doublequote})")];
          fn = "sum";
          extra = ''
            |> map(fn: (r) => ({r with _value: r._value / float(v: int(v: v.windowPeriod) / int(v: 1s))}))
          '';
          createEmpty = true;
        };
      };
      stats = {
        spec.title = "Stats";
        spec.vizConfig.group = "stat";
        spec.vizConfig.spec.options.text = {
          titleSize = 18;
          valueSize = 20;
        };
        spec.vizConfig.spec.options.orientation = "horizontal";
        spec.vizConfig.spec.fieldConfig.defaults.color.mode = "palette-classic";
        spec.data.spec.queryOptions.interval = interval;
        influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
        influx.filter.mac-address = "\${macaddress}";
        influx.filter._field = [
          "last-activity-ns"
          "p-throughput"
          "rx-bytes"
          "rx-frame-bytes"
          "rx-frames"
          "rx-hw-frame-bytes"
          "rx-hw-frames"
          "rx-packets"
          "rx-rate"
          "signal-strength"
          "signal-strength-ch0"
          "signal-strength-ch1"
          "signal-strength-ch2"
          "signal-strength-rate"
          "signal-to-noise"
          #"strength-at-rates"
          #"strength-at-rates-age-ns"
          "tx-bytes"
          "tx-ccq"
          "tx-frame-bytes"
          "tx-frames"
          "tx-frames-timed-out"
          "tx-hw-frame-bytes"
          "tx-hw-frames"
          "tx-packets"
          "tx-rate"
          "uptime-ns"
        ];
        influx.fn = "mean";
        fields.last-activity-ns.unit = "ns";
        fields.p-throughput.unit = "Kbits";
        fields.rx-bytes.unit = "bytes";
        fields.rx-frame-bytes.unit = "bytes";
        fields.rx-hw-frame-bytes.unit = "bytes";
        fields.rx-rate.unit = "bps";
        fields.signal-strength.unit = "dBm";
        fields.signal-strength-rate.unit = "bps";
        fields.signal-strength-ch0.unit = "dBm";
        fields.signal-strength-ch1.unit = "dBm";
        fields.signal-strength-ch2.unit = "dBm";
        fields.signal-to-noise.unit = "dB";
        #fields.strength-at-rates.unit = "dBm";
        #fields.strength-at-rates-age-ns.unit = "ns";
        fields.tx-bytes.unit = "bytes";
        fields.tx-ccq.unit = "percent";
        fields.tx-frame-bytes.unit = "bytes";
        fields.tx-hw-frame-bytes.unit = "bytes";
        fields.tx-rate.unit = "bps";
        fields.uptime-ns.unit = "ns";
        influx.extra = ''
          |> drop(columns: ["_start", "_stop", "_measurement", "agent_host", "host", "hostname", "mac-address", "last-ip", "authentication-type", "encryption", "group-encryption", "interface"])
        '';
        # For use with the "dateTimeFromNow" unit
        # |> map(fn: (r) => ({r with _value: if (r._field == "last-activity-ns" or r._field == "uptime-ns") then float(v: uint(v: date.sub(from: r._time, d: duration(v: int(v: r._value)))))/1000000. else r._value}))
      };
      logs = {
        datasourceName = "loki";
        spec.title = "Recent Logs";
        spec.vizConfig.group = "logs";
        spec.data.spec.queries = [{
          spec.query.spec.expr = ''
            {source_type="mikrotik"}
            |~ `(?i)''${macaddress}`
            | json message="message"
            | line_format `{{if .name}}{{.name}}{{else}}{{.topic}}{{if and (ne .subtopic "<null>") (ne .subtopic "")}},{{.subtopic}}{{end}}{{end}} {{or .message __line__}}`
            | drop message,detected_level,service_name,subtopic="<null>",timestamp_end,__error__,__error_details__
          '';
          spec.query.spec.queryType = "range";
        }];
        spec.vizConfig.spec.options.showTime = true;
      };
    };
  };
}
