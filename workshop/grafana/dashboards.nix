{ config, pkgs, lib, ... }:

let
  blankDashboard = {
    annotations.list = [{
      builtIn = 1;
      datasource.type = "grafana";
      datasource.uid = "-- Grafana --";
      enable = true;
      hide = true;
      iconColor = "rgba(0, 211, 255, 1)";
      name = "Annotations & Alerts";
      target.limit = 100;
      target.matchAny = false;
      target.tags = [];
      target.type = "dashboard";
      type = "dashboard";
    }];
    #version = 0;
    schemaVersion = 38;
    #editable = true;
    #graphTooltip = 0;
    #links = [];
    #liveNow = false;
    #fiscalYearStartMonth = 0;
    #refresh = "";
    #style = "dark";
    #tags = [];
    #templating.list = [];
    #time.from = "now-6h";
    #time.to = "now";
    #timepicker = {};
    #timezone = "";
    #weekStart = "";
    panels = [];
  };
  influxDatasource = {
    uid = "mAU691fGz";
    type = "influxdb";
  };
  muninGraphs = [
    {
      # diskstats_iops
      graph_title = "Disk IOs per device";
      graph_vlabel = "IOs/second read (-) / write (+)";
      graph_category = "disk";
      influx.filter._measurement = "diskio";
      influx.filter._field = ["reads" "writes"];
      influx.fn = "derivative";
      influx.pivot = true;
      unit = "iops";
      fields.reads.negative = true;
    }
    {
      # diskstats_latency
      graph_title = "Disk latency per device";
      graph_vlabel = "Average IO Wait";
      graph_category = "disk";
      influx.filter._measurement = "diskio";
      influx.filter._field = ["read_time" "write_time" "reads" "writes"];
      influx.fn = "derivative";
      influx.pivot = true;
      influx.extra = ''
        |> map(fn: (r) => ({_time: r._time, host: r.host, name: r.name, _value: if (r.reads + r.writes == 0) then 0. else float(v: r.read_time + r.write_time) / float(v: r.reads + r.writes)}))
      '';
      unit = "ms";
    }
    {
      # diskstats_throughput
      graph_title = "Throughput per device";
      graph_vlabel = "Bytes/second read (-) / write (+)";
      graph_category = "disk";
      graph_info = "This graph shows averaged throughput for the given disk in bytes.  Higher throughput is usualy linked with higher service time/latency (separate graph).";
      influx.filter._measurement = "diskio";
      influx.filter._field = ["read_bytes" "write_bytes"];
      influx.fn = "derivative";
      influx.pivot = true;
      unit = "binBps";
      fields.read_bytes.negative = true;
    }
    {
      # diskstats_utilization
      graph_title = "Utilization per device";
      graph_vlabel = "% busy";
      graph_category = "disk";
      graph_args.lower-limit = 0;
      graph_args.upper-limit = 1;
      influx.filter._measurement = "diskio";
      influx.filter._field = "io_time";
      influx.fn = "derivative";
      # Convert ms/s to s/s
      influx.extra = ''
        |> map(fn: (r) => ({r with _value: r._value / 1000.}))
      '';
      unit = "percentunit";
    }
    {
      # df
      graph_title = "Disk usage in percent";
      graph_category = "disk";
      graph_args.lower-limit = 0;
      graph_args.upper-limit = 100;
      influx.filter._measurement = "disk";
      influx.filter._field = "used_percent";
      influx.fn = "mean";
      unit = "percent";
    }
    {
      # (new) df_bytes
      graph_title = "Disk usage";
      graph_category = "disk";
      influx.filter._measurement = "disk";
      influx.filter._field = "used";
      influx.filter.fstype = { op = "!="; values = ["nullfs" "afs"]; };
      influx.fn = "mean";
      unit = "bytes";
    }
    {
      # df_inode
      graph_title = "Inode usage in percent";
      graph_category = "disk";
      graph_args.lower-limit = 0;
      graph_args.upper-limit = 1;
      influx.filter._measurement = "disk";
      influx.filter._field = ["inodes_used" "inodes_total"];
      influx.fn = "mean";
      influx.pivot = true;
      influx.extra = ''
        |> map(fn: (r) => ({r with _value: r.inodes_used / r.inodes_total}))
        |> drop(columns: ["inodes_used", "inodes_total"])
      '';
      unit = "percentunit";
    }
    {
      # iostat
      graph_title = "IOstat";
      graph_category = "disk";
      graph_vlabel = "blocks per second read (-) / written (+)";
      graph_info = "This graph shows the I/O to and from block devices.";
      influx.filter._measurement = "diskio";
      influx.filter._field = ["read_bytes" "write_bytes"];
      influx.fn = "derivative";
      influx.pivot = true;
      # TODO: Is this more complicated than dividing by 512?
      influx.extra = ''
        |> map(fn: (r) => ({r with read_bytes: r.read_bytes / 512., write_bytes: r.write_bytes / 512.}))
      '';
      fields.read_bytes.negative = true;
    }
    {
      # iostat_ios
      graph_title = "IO Service time";
      graph_category = "disk";
      graph_vlabel = "Average IO Wait";
      graph_info = "For each applicable disk device this plugin shows the latency (or delay) for I/O operations on that disk device.  The delay is in part made up of waiting for the disk to flush the data, and if data arrives at the disk faster than it can read or write it then the delay time will include the time needed for waiting in the queue.";
      graph_args.logarithmic = true;
      influx.filter._measurement = "diskio";
      influx.filter._field = ["read_time" "write_time" "reads" "writes"];
      influx.fn = "derivative";
      influx.pivot = true;
      influx.extra = ''
        |> map(fn: (r) => ({_time: r._time, host: r.host, name: r.name,
          reads: float(v: r.read_time) / float(v: r.reads),
          writes: float(v: r.write_time) / float(v: r.writes)
        }))
      '';
      unit = "ms";
    }
    {
      # smart_
      graph_title = "S.M.A.R.T values for drive \${smart_device}";
      graph_category = "disk";
      graph_vlabel = "Attribute S.M.A.R.T value";
      graph_args.lower-limit = 0;
      influx.filter._measurement = "smart_attribute";
      influx.filter._field = "value";
      influx.filter.device = "\${smart_device}";
      influx.fn = "mean";
      influx.extra = ''
        |> keep(columns: ["_time", "_value", "host", "model", "serial_no", "name"])
      '';
      repeat = "smart_device";
    }
    {
      # if_
      graph_title = "\${interface} traffic";
      graph_category = "network";
      graph_vlabel = "bits in (-) / out (+) per second";
      graph_info = "This graph shows the traffic of the \${interface} network interface. Please note that the traffic is shown in bits per second, not bytes.";
      influx.filter._measurement = "net";
      influx.filter._field = ["bytes_recv" "bytes_sent"];
      influx.filter.interface = "\${interface}";
      influx.fn = "derivative";
      influx.extra = ''
        |> map(fn: (r) => ({r with _value: 8. * r._value}))
      '';
      fields.bytes_recv.negative = true;
      repeat = "interface";
      unit = "bps";
    }
    {
      # if_err_
      graph_title = "\${interface} errors";
      graph_category = "network";
      graph_vlabel = "packets in (-) / out (+) per second";
      graph_info = "This graph shows the amount of errors, packet drops, and collisions on the \${interface} network interface.";
      influx.filter._measurement = "net";
      influx.filter._field = ["err_in" "err_out"];
      influx.filter.interface = "\${interface}";
      influx.fn = "derivative";
      fields.err_in.negative = true;
      repeat = "interface";
      unit = "pps";
      right = true;
    }
    {
      # netstat
      graph_title = "Netstat";
      graph_category = "network";
      graph_vlabel = "TCP connection rate";
      graph_info = "This graph shows the TCP activity of all the network interfaces combined.";
      graph_args.logarithmic = true;
      influx = [
        {
          filter._measurement = "net";
          filter._field = ["tcp_activeopens" "tcp_passiveopens" "tcp_attemptfails" "tcp_estabresets"];
          fn = "derivative";
          extra = ''
            |> drop(columns: ["interface"])
          '';
        }
        {
          filter._measurement = "netstat";
          filter._field = "tcp_established";
          fn = "mean";
          extra = ''
            |> drop(columns: ["interface"])
          '';
        }
      ];
      field.tcp_established.properties = {
        unit = "none";
        "custom.axisPlacement" = "right";
        "custom.axisLabel" = "TCP connections";
      };
    }
    # http_loadtime
    # fw_packets
    # graph_category postfix
    # graph_category processes
    {
      # forks
      graph_title = "Fork rate";
      graph_category = "processes";
      graph_info = "This graph shows the number of forks (new processes started) per second.";
      graph_args.lower-limit = 0;
      influx.filter._measurement = "kernel";
      influx.filter._field = "processes_forked";
      influx.fn = "derivative";
      unit = "hertz";
    }
    {
      # processes
      graph_title = "Processes";
      graph_category = "processes";
      graph_info = "This graph shows the number of processes";
      graph_args.lower-limit = 0;
      stacking = true;
      influx.filter._measurement = "processes";
      influx.filter._field = { op = "!="; values = ["total" "total_threads"]; };
      influx.fn = "mean";
    }
    # proc_pri
    # threads
    # vmstat
    # graph_category sensors
    # acpi
    # hddtemp_smartctl
    # sensors_fan
    # sensors_temp
    # sensors_volt
    # graph_category system
    # cpu
    # cpuspeed
    # entropy
    # interrupts
    # irqstats
    # load
    # memory
    # open_files
    # open_inodes
    # swap
    # uptime
    # users
  ];
  fluxValue = with builtins; v:
    if isInt v || isFloat v then toString v
    else if isString v then ''"${lib.escape [''"''] v}"''
    else abort "Unknown type";
  fluxFilter = with builtins; field: v:
    if isAttrs v then
      lib.concatMapStringsSep
        (if v.op == "!=" then " and " else " or ")
        (value: ''r[${fluxValue field}] ${v.op} ${fluxValue value}'')
        (lib.toList v.values)
    else fluxFilter field { op = "=="; values = v; }
  ;
  mergeAttrs = with lib; fold recursiveUpdate {};
  muninPanel = g: {
    gridPos = {
      w = 12;
      h = 8;
      x = if (g.right or false) then 12 else 0;
    };
    title = g.graph_title;
    type = "timeseries";
    interval = "10s";
    fieldConfig.defaults = mergeAttrs [
      {
        unit = g.unit or "none";
      }
      (lib.optionalAttrs (g.stacking or false) {
        custom.stacking.mode = "normal";
        custom.fillOpacity = 10;
      })
      (lib.optionalAttrs (g ? graph_vlabel) {
        custom.axisLabel = g.graph_vlabel;
      })
      (lib.optionalAttrs (g ? graph_args.lower-limit) {
        min = g.graph_args.lower-limit;
      })
      (lib.optionalAttrs (g ? graph_args.upper-limit) {
        max = g.graph_args.upper-limit;
      })
      (lib.optionalAttrs (g.graph_args.logarithmic or false) {
        custom.scaleDistribution.type = "log";
        custom.scaleDistribution.log = 10;
      })
    ];
    fieldConfig.overrides = lib.mapAttrsToList (field: options: {
      matcher.id = "byName";
      matcher.options = field;
      properties = lib.mapAttrsToList (id: value: {
        inherit id value;
      }) ((options.properties or {}) // lib.optionalAttrs (options.negative or false) {
        "custom.transform" = "negative-Y";
      });
    }) (g.field or {});
    datasource = influxDatasource;
    targets = let
      filters = lib.mapAttrsToList (field: values:
        ''|> filter(fn: (r) => ${fluxFilter field values})'');
    in lib.imap0 (i: influx: {
      datasource = influxDatasource;
      query = ''
        from (bucket: v.defaultBucket)
        |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
        ${lib.concatStringsSep "\n" (filters influx.filter)}
        |> filter(fn: (r) => r.host =~ /^''${host:regex}$/)
      '' + (if influx.fn == "derivative" then ''
        |> aggregateWindow(every: v.windowPeriod, fn: last)
        |> derivative(unit: 1s, nonNegative: true)
      '' else ''
        |> aggregateWindow(every: v.windowPeriod, fn: ${influx.fn}, createEmpty: false)
      '') + lib.optionalString (influx.pivot or false) ''
        |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
        |> drop(columns: ["_start", "_stop"])
      '' + (influx.extra or "");
      refId = lib.elemAt [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ] i;
    }) (lib.toList g.influx);
  } // lib.optionalAttrs (g ? repeat) {
    repeat = g.repeat;
    repeatDirection = "v";
  } // lib.optionalAttrs (g ? graph_info) {
    description = g.graph_info;
  };
in {
  config = {
    services.grafana.provision.dashboards.settings.providers = let
      dashboards = {
        "Experimental/munin-generated" = {
          uid = "Pd7zBps4z";
          title = "Munin Generated";
          templating.list = let
            variables = {
              host = {
                predicate = ''r["_measurement"] == "system"'';
                extra.label = "Host";
                extra.multi = true;
              };
              smart_device = {
                tag = "device";
                predicate = ''r["_measurement"] == "smart_device" and r.host =~ /''${host:regex}/'';
                extra.label = "SMART Device";
              };
              interface = {
                predicate = ''r["_measurement"] == "net" and r.interface != "all" and r.host =~ /''${host:regex}/'';
              };
            };
          in lib.mapAttrsToList (name: args: lib.recursiveUpdate rec {
            tag = args.tag or name;
            query = ''
              import "influxdata/influxdb/schema"

              schema.tagValues(
                bucket: v.defaultBucket,
                tag: ${fluxValue tag},
                predicate: (r) => ${args.predicate},
                start: v.timeRangeStart,
                stop: v.timeRangeStop
              )
            '';
            definition = query;
            datasource = influxDatasource;
            includeAll = true;
            inherit name;
            type = "query";
          } (args.extra or {})) variables;
          panels = map muninPanel muninGraphs;
        };
      };
      dashboardFormat = pkgs.formats.json {};
      dashboardPkg = pkgs.linkFarm "grafana-dashboards" (
        lib.mapAttrs' (name: d: lib.nameValuePair "${name}.json" (
          dashboardFormat.generate "${name}.json" (lib.recursiveUpdate blankDashboard d)
        )) dashboards
      );
    in [{
      options.path = "${dashboardPkg}";
      options.foldersFromFilesStructure = true;
    }];
  };
}
