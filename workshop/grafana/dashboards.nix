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
      fields.reads.custom.transform = "negative-Y";
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
      fields.read_bytes.custom.transform = "negative-Y";
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
      fields.read_bytes.custom.transform = "negative-Y";
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
      fields.bytes_recv.custom.transform = "negative-Y";
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
      fields.err_in.custom.transform = "negative-Y";
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
      fields.tcp_established = {
        unit = "none";
        custom.axisPlacement = "right";
        custom.axisLabel = "TCP connections";
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
      unit = "short";
    }
    # proc_pri
    {
      # threads
      graph_title = "Number of threads";
      graph_category = "processes";
      graph_vlabel = "number of threads";
      graph_info = "This graph shows the number of threads.";
      graph_args.lower-limit = 0;
      influx.filter._measurement = "processes";
      influx.filter._field = "total_threads";
      influx.fn = "mean";
      unit = "short";
    }
    {
      # vmstat
      graph_title = "VMstat";
      graph_category = "processes";
      graph_vlabel = "process states";
      graph_args.lower-limit = 0;
      influx.filter._measurement = "processes";
      influx.filter._field = ["blocked" "running"];
      influx.fn = "mean";
      unit = "short";
    }
    # graph_category sensors
    # acpi
    {
      # hddtemp_smartctl
      graph_title = "HDD temperature";
      graph_category = "sensors";
      influx.filter._measurement = "smart_device";
      influx.filter._field = "temp_c";
      influx.fn = "mean";
      influx.extra = ''
        |> drop(columns: ["capacity", "enabled"])
      '';
      unit = "celsius";
    }
    # (new) temp_gopsutil
    {
      # sensors_fan
      graph_title = "Fans";
      graph_category = "sensors";
      influx.filter._measurement = "sensors";
      influx.filter._field = "fan_input";
      influx.fn = "mean";
      unit = "rotrpm";
    }
    {
      # sensors_temp
      graph_title = "Temperatures";
      graph_category = "sensors";
      influx.filter._measurement = "sensors";
      influx.filter._field = "temp_input";
      influx.fn = "mean";
      unit = "celsius";
    }
    {
      # sensors_volt
      graph_title = "Voltages";
      graph_category = "sensors";
      influx.filter._measurement = "sensors";
      influx.filter._field = "in_input";
      influx.fn = "mean";
      unit = "volt";
      graph_args.logarithmic = true;
    }
    # graph_category system
    {
      # cpu
      graph_title = "CPU usage";
      graph_category = "system";
      graph_info = "This graph shows how CPU time is spent.";
      influx.filter._measurement = "cpu";
      influx.filter._field = { op = "=~"; values = "^time"; };
      influx.fn = "derivative";
      influx.imports = ["strings"];
      influx.extra = ''
        |> group(columns: ["_measurement", "_field", "_time", "host"])
        |> sum()
        |> group(columns: ["_measurement", "_field", "host"])
        |> map(fn: (r) => ({r with _field: strings.trimPrefix(v: r._field, prefix: "time_")}))
        |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
      '';
      stacking = true;
      unit = "percentunit";
      fields.idle.color.mode = "fixed";
      fields.system.color = { mode = "fixed"; fixedColor = "green"; };
      fields.user.color = { mode = "fixed"; fixedColor = "blue"; };
      fields.nice.color = { mode = "fixed"; fixedColor = "orange"; };
    }
    # cpuspeed
    {
      # entropy
      graph_title = "Available entropy";
      graph_category = "system";
      graph_info = "This graph shows the amount of entropy available in the system.";
      influx.filter._measurement = "kernel";
      influx.filter._field = "entropy_avail";
      influx.fn = "mean";
    }
    {
      # interrupts
      graph_title = "Interrupts and context switches";
      graph_category = "system";
      graph_info = "This graph shows the number of interrupts and context switches on the system. These are typically high on a busy system.";
      graph_vlabel = "interrupts & ctx switches";
      influx.filter._measurement = "kernel";
      influx.filter._field = ["context_switches" "interrupts"];
      influx.fn = "derivative";
      unit = "hertz";
    }
    {
      # irqstats
      graph_title = "Individual interrupts";
      graph_category = "system";
      graph_info = "Shows the number of different IRQs received by the kernel.  High disk or network traffic can cause a high number of interrupts (with good hardware and drivers this will be less so). Sudden high interrupt activity with no associated higher system activity is not normal.";
      graph_vlabel = "interrupts";
      graph_args.logarithmic = true;
      influx.filter._measurement = "interrupts";
      influx.filter._field = "total";
      influx.fn = "derivative";
      influx.extra = ''
        |> map(fn: (r) => ({_time: r._time, host: r.host, _value: r._value, _field: if exists r.device then r.device else if exists r.type then r.type else r.irq}))
      '';
      unit = "hertz";
    }
    {
      # load
      graph_title = "Load average (1m)";
      graph_category = "system";
      graph_info = ''The load average of the machine describes how many processes are in the run-queue (scheduled to run "immediately").'';
      graph_vlabel = "load";
      influx.filter._measurement = "system";
      influx.filter._field = "load1";
      influx.fn = "mean";
      unit = "short";
    }
    {
      # memory
      graph_title = "Memory usage";
      graph_category = "system";
      graph_info = "This graph shows what the machine uses memory for.";
      influx.filter._measurement = "mem";
      influx.filter._field = [
        # apps = r.total - r.free - r.buffered - r.cached - r.slab - r.page_tables - r.swap_cached
        "total"
        "sreclaimable"
        "page_tables"
        "swap_cached"
        "slab"
        "shared"
        "cached"
        "buffered"
        "free"
        # swap = swap_total - swap_free
        "swap_total"
        "swap_free"
        "vmalloc_used"
        "committed_as"
        "mapped"
        "active"
        "inactive"
        # mac
        "wired"
      ];
      influx.fn = "mean";
      influx.extra = ''
        |> group(columns: ["_time", "_field"])
        |> sum()
        |> group()
        |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
        // swap = swap_total - swap_free
        // apps = MemTotal - MemFree - Buffers - Cached - Slap - PageTables - Percpu - SwapCached
        |> map(fn: (r) => ({r with
          swap: if exists r.swap_total then r.swap_total - r.swap_free else 0.,
          cached: r.cached - r.sreclaimable,
          apps:
            r.total
            - r.free
            - (if exists r.wired then r.wired else 0.)
            - (if exists r.buffered then r.buffered else 0.)
            - (if exists r.cached then r.cached - r.sreclaimable else 0.)
            - (if exists r.slab then r.slab else 0.)
            - (if exists r.page_tables then r.page_tables else 0.)
            - (if exists r.swap_cached then r.swap_cached else 0.)
        }))
        |> drop(columns: ["_start", "_stop", "total", "sreclaimable", "swap_total", "swap_free"])
      '';
      stacking = true;
      defaults = {
        custom.fillOpacity = 50;
      };
      unit = "bytes";
      fields = {
        free.color.mode = "fixed";
        swap.color = { mode = "fixed"; fixedColor = "#ff0000"; };
      } // lib.genAttrs [
        "mapped"
        "active"
        "committed_as"
        "inactive"
        "vmalloc_used"
      ] (_: {
        custom.lineWidth = 2;
        custom.fillOpacity = 0;
        custom.stacking.mode = "none";
      });
      fieldOrder = [
        "_time"
        "apps"
        "page_tables"
        "swap_cached"
        "slab"
        "shared"
        "cached"
        "buffered"
        "free"
        "swap"
        "vmalloc_used"
        "committed_as"
        "mapped"
        "active"
        "inactive"
      ];
    }
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
        (if v.op == "!=" || v.op == "!~" then " and " else " or ")
        (value: ''r[${fluxValue field}] ${v.op} ${if v.op == "=~" || v.op == "!~" then "/${value}/" else fluxValue value}'')
        (lib.toList v.values)
    else fluxFilter field { op = "=="; values = v; }
  ;
  flattenAttrs = with builtins; with lib; pkgs.unstable.lib.foldlAttrs (acc: name: value:
    if isAttrs value then
      acc // (mapAttrs' (k: v: nameValuePair "${name}.${k}" v) (flattenAttrs value))
    else
      acc // { "${name}" = value; }
  ) {};
  toProperties = with builtins; with lib; attrs:
    (removeAttrs attrs ["custom"]) //
    (mapAttrs' (k: v: nameValuePair "custom.${k}" v) (attrs.custom or {}));
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
    options.tooltip.mode = "multi";
    options.legend = {
      showLegend = true;
      displayMode = "table";
      placement = "bottom";
      calcs = [
        "lastNotNull"
        "min"
        "mean"
        "max"
      ];
      sortBy = "Last *";
      sortDesc = true;
    };
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
      (g.defaults or {})
    ];
    fieldConfig.overrides = lib.mapAttrsToList
      (field: options: {
        matcher.id = "byName";
        matcher.options = field;
        properties = lib.mapAttrsToList (id: value: {
          inherit id value;
        }) (toProperties options);
      })
      (g.fields or {});
    datasource = influxDatasource;
    targets = let
      filters = lib.mapAttrsToList (field: values:
        ''|> filter(fn: (r) => ${fluxFilter field values})'');
    in lib.imap0 (i: influx: {
      datasource = influxDatasource;
      query =
        lib.concatMapStringsSep "\n" (x: ''import ${fluxValue x}'') (influx.imports or []) + ''
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
  } // lib.optionalAttrs (g ? fieldOrder) {
    transformations = [{
      id = "organize";
      options.indexByName = builtins.listToAttrs (lib.imap0 (i: key: lib.nameValuePair key i) g.fieldOrder);
    }];
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
