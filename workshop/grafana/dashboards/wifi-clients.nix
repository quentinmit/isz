{ config, options, pkgs, lib, ... }:
{
  config.isz.grafana.dashboards.wifi-clients = {
    uid = "vQ9bVarMz";
    title = "WiFi Clients";
    tags = [ "home" "wifi" ];
    defaultDatasourceName = "workshop";
    panels = let
      interval = config.isz.telegraf.interval.mikrotik;
    in [
      {
        panel = {
          gridPos = { x = 0; y = 0; w = 24; h = 20; };
          title = "WiFi Clients";
          type = "table";
        };
        panel.fieldConfig.defaults = {
          custom.filterable = true;
        };
        influx.query = ''
          import "join"

          interfaces1 = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/interface/wireless")
            |> filter(fn: (r) => r["_field"] == "running")
            |> last()
            |> group(columns: ["hostname"])
            |> map(fn: (r) => ({r with "master-interface": if exists r["master-interface"] then r["master-interface"] else r["name"]}))
          interfaces2 = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/interface/wireless")
            |> filter(fn: (r) => r["_field"] == "running")
            |> last()
            |> group(columns: ["hostname"])
            // Should not be necessary but causes a panic if missing
            |> map(fn: (r) => ({r with "master-interface": if exists r["master-interface"] then r["master-interface"] else r["name"]}))

          interfaces = join.left(
            left: interfaces1,
            right: interfaces2,
            on: (l, r) => l["master-interface"] == r["name"],
            as: (l, r) => ({
              "hostname": l.hostname,
              "name": l.name,
              "ssid": l.ssid,
              "band": if exists r.band then r.band else l.band,
            })
            )
            |> group(columns: ["hostname"])

          registrations = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/interface/wireless/registration-table")
            |> filter(fn: (r) => r["_field"] == "tx-rate-name" or r._field == "rx-rate-name" or r._field == "uptime-ns" or r._field == "signal-strength" or r._field == "tx-ccq")
            |> group(columns: ["_measurement", "_field", "_start", "_stop", "agent_host", "hostname", "interface", "mac-address"])
            |> last()
            |> pivot(rowKey: ["_time", "last-ip"], columnKey: ["_field"], valueColumn: "_value")
            |> group(columns: ["hostname"])

          leases = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/ip/dhcp-server/lease")
            |> filter(fn: (r) => r["_field"] == "active-address" or r._field == "status")
            |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> group(columns: ["hostname", "mac-address"])
            |> sort(columns: ["_time"])
            |> last(column: "status")
            |> group(columns: ["hostname"])

          registrations2 = join.left(
            left: registrations,
            right: leases,
            on: (l, r) => l["mac-address"] == r["mac-address"],
            as: (l, r) => ({
              "hostname": l.hostname,
              "interface": l.interface,
              "last-seen": l._time,
              "mac-address": l["mac-address"],
              "last-ip": l["last-ip"],
              "active-address": r["active-address"],
              "known": exists r.comment,
              "comment": r.comment,
              "rx-rate": l["rx-rate-name"],
              "tx-rate": l["tx-rate-name"],
              "tx-ccq": l["tx-ccq"],
              "uptime": l["uptime-ns"],
              "signal-strength": l["signal-strength"]
            })
          )
          |> sort(columns: ["interface", "active-address"])
          |> sort(columns: ["last-seen"], desc: true)

          join.left(
            left: registrations2,
            right: interfaces,
            on: (l, r) => l["interface"] == r["name"],
            as: (l, r) => ({
              "hostname": l.hostname,
              "interface": l.interface,
              "band": r.band,
              "ssid": r.ssid,
              "last-seen": l["last-seen"],
              "mac-address": l["mac-address"],
              "last-ip": l["last-ip"],
              "active-address": l["active-address"],
              "known": l.known,
              "comment": l.comment,
              "rx-rate": l["rx-rate"],
              "tx-rate": l["tx-rate"],
              "tx-ccq": l["tx-ccq"],
              "uptime": l["uptime"],
              "signal-strength": l["signal-strength"]
            })
            )
            |> drop(columns: ["hostname"])
            |> yield()
        '';
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
      }
      {
        panel = {
          gridPos = { x = 0; y = 20; w = 12; h = 11; };
          title = "TX Rate";
          inherit interval;
          options.tooltip.mode = "multi";
          options.tooltip.sort = "desc";
          options.legend.showLegend = false;
        };
        panel.fieldConfig.defaults = {
          displayName = ''''${__field.labels.interface} ''${__field.labels.mac-address} ''${__field.labels.comment}'';
          unit = "bps";
          links = [{
            title = "Show details";
            url = ''/d/eXssGz84k/wifi-client?orgId=1&var-macaddress=''${__field.labels.mac-address}'';
          }];
        };
        influx.query = ''
          import "join"

          rates = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/interface/wireless/registration-table")
            |> filter(fn: (r) => r["_field"] == "tx-rate")
            |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false) // true
            |> group(columns: ["hostname", "mac-address"])

          leases = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/ip/dhcp-server/lease")
            |> filter(fn: (r) => r._field == "status")
            |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> group(columns: ["hostname", "mac-address"])
            |> sort(columns: ["_time"])
            |> last(column: "status")
            |> map(fn: (r) => ({r with comment: if exists r.comment then r.comment else ""}))
            |> keep(columns: ["hostname", "mac-address", "comment"])

          join.left(
            left: rates,
            right: leases,
            on: (l, r) => l["mac-address"] == r["mac-address"],
            as: (l, r) => ({
              "hostname": l.hostname,
              "interface": l.interface,
              "mac-address": l["mac-address"],
              "last-ip": l["last-ip"],
              "comment": r.comment,
              "_value": l._value,
              "_time": l._time,
              "_start": l._start,
              "_stop": l._stop,
              "_measurement": l._measurement,
              "_field": l._field,
            })
          )
          |> group(columns: ["_measurement", "_field", "_start", "_stop", "hostname", "interface", "mac-address", "comment"])
          |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: true)
          |> yield()
        '';
      }
      {
        panel = {
          gridPos = { x = 12; y = 20; w = 12; h = 11; };
          title = "Throughput";
          inherit interval;
          options.tooltip.mode = "multi";
          options.tooltip.sort = "desc";
          options.legend.showLegend = false;
        };
        panel.fieldConfig.defaults = {
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
        influx.query = ''
          import "join"

          rates = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/interface/wireless/registration-table")
            |> filter(fn: (r) => r["_field"] == "tx-bytes" or r._field == "rx-bytes")
            |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
            |> derivative(nonNegative: true)
            |> group(columns: ["hostname", "mac-address"])

          leases = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "mikrotik-/ip/dhcp-server/lease")
            |> filter(fn: (r) => r._field == "status")
            |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> group(columns: ["hostname", "mac-address"])
            |> sort(columns: ["_time"])
            |> last(column: "status")
            |> map(fn: (r) => ({r with comment: if exists r.comment then r.comment else r["mac-address"]}))
            |> keep(columns: ["hostname", "mac-address", "comment"])

          join.left(
            left: rates,
            right: leases,
            on: (l, r) => l["mac-address"] == r["mac-address"],
            as: (l, r) => ({
              "hostname": l.hostname,
              "interface": l.interface,
              "mac-address": l["mac-address"],
              "comment": if exists r.comment then r.comment else l["mac-address"],
              "_time": l._time,
              "_start": l._start,
              "_stop": l._stop,
              "_measurement": l._measurement,
              "_field": l._field,
              "_value": l._value,
            })
          )
          |> group(columns: ["_measurement", "_field", "_start", "_stop", "hostname", "interface", "mac-address", "comment"])
          |> yield()
        '';
      }
    ];
  };
  config.isz.grafana.dashboards.wifi-client = {
    uid = "eXssGz84k";
    title = "WiFi Client";
    defaultDatasourceName = "workshop";
    variables = {
      macaddress = {
        query = ''
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
        extra.label = "MAC address";
        extra.regex = ''/^(?<text>(?<value>[^ ]+).*)/'';
        extra.includeAll = false;
      };
    };
    links = [
      {
        tags = ["wifi"];
        type = "dashboards";
      }
    ];
    panels = let
      interval = config.isz.telegraf.interval.mikrotik;
    in [
      {
        panel = {
          gridPos = { x = 0; y = 0; w = 20; h = 3; };
          title = "";
          type = "table";
        };
        panel.fieldConfig.defaults = {
        };
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
      }
      {
        panel = {
          gridPos = { x = 0; y = 3; w = 10; h = 8; };
          title = "Wireless Rate";
          options.tooltip.mode = "multi";
          inherit interval;
        };
        panel.fieldConfig.defaults = {
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
      }
      {
        panel = {
          gridPos = { x = 10; y = 3; w = 10; h = 8; };
          title = "Throughput";
          options.tooltip.mode = "multi";
          inherit interval;
        };
        panel.fieldConfig.defaults = {
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
      }
      {
        panel = {
          gridPos = { x = 0; y = 11; w = 10; h = 8; };
          title = "Signal Strength at Rate";
          options.tooltip.mode = "multi";
          inherit interval;
        };
        panel.fieldConfig.defaults = {
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
      }
      {
        panel = {
          gridPos = { x = 10; y = 11; w = 10; h = 8; };
          title = "TX CCQ";
          inherit interval;
        };
        panel.fieldConfig.defaults = {
          unit = "percent";
        };
        influx.filter._measurement = "mikrotik-/interface/wireless/registration-table";
        influx.filter._field = ["tx-ccq"];
        influx.filter.mac-address = "\${macaddress}";
        influx.fn = "mean";
        influx.createEmpty = true;
      }
      {
        panel = {
          gridPos = { x = 20; y = 0; w = 4; h = 36; };
          title = "Stats";
          type = "stat";
          options.text = {
            titleSize = 18;
            valueSize = 20;
          };
          options.orientation = "horizontal";
          inherit interval;
        };
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
      }
    ];
  };
}
