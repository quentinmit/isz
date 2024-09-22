{ config, options, pkgs, lib, ... }:
{
  config.isz.grafana.dashboards.munin = {
    uid = "Pd7zBps4z";
    title = "Munin";
    defaultDatasourceName = "workshop";
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
      battery = {
        tag = "device";
        predicate = ''r._measurement == "power_supply" and r.type == "Battery" and r.host =~ /''${host:regex}/'';
        extra.hide = 2;
        extra.skipUrlSync = true;
      };
    };
    munin.graphs = {
      disk.diskstats_iops = {
        graph_title = "Disk IOs per device";
        graph_vlabel = "IOs/second read (-) / write (+)";
        influx.filter._measurement = "diskio";
        influx.filter._field = ["reads" "writes"];
        influx.fn = "derivative";
        influx.pivot = true;
        unit = "iops";
        fields.reads.custom.transform = "negative-Y";
      };
      disk.diskstats_latency = {
        graph_title = "Disk latency per device";
        graph_vlabel = "Average IO Wait";
        influx.filter._measurement = "diskio";
        influx.filter._field = ["read_time" "write_time" "reads" "writes"];
        influx.fn = "derivative";
        influx.pivot = true;
        influx.extra = ''
        |> map(fn: (r) => ({_time: r._time, host: r.host, name: r.name, _value: if (r.reads + r.writes == 0) then 0. else float(v: r.read_time + r.write_time) / float(v: r.reads + r.writes)}))
      '';
        unit = "ms";
      };
      disk.diskstats_throughput = {
        graph_title = "Throughput per device";
        graph_vlabel = "Bytes/second read (-) / write (+)";
        graph_info = "This graph shows averaged throughput for the given disk in bytes.  Higher throughput is usualy linked with higher service time/latency (separate graph).";
        influx.filter._measurement = "diskio";
        influx.filter._field = ["read_bytes" "write_bytes"];
        influx.fn = "derivative";
        influx.pivot = true;
        unit = "binBps";
        fields.read_bytes.custom.transform = "negative-Y";
      };
      disk.diskstats_utilization = {
        graph_title = "Utilization per device";
        graph_vlabel = "% busy";
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
      };
      disk.df = {
        graph_title = "Disk usage in percent";
        graph_args.lower-limit = 0;
        graph_args.upper-limit = 100;
        influx.filter._measurement = "disk";
        influx.filter._field = "used_percent";
        influx.fn = "mean";
        unit = "percent";
      };
      disk.df_bytes = { # new
        graph_title = "Disk usage";
        influx.filter._measurement = "disk";
        influx.filter._field = "used";
        influx.filter.fstype = { op = "!="; values = ["nullfs" "afs"]; };
        influx.fn = "mean";
        unit = "bytes";
      };
      disk.df_inode = {
        graph_title = "Inode usage in percent";
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
      };
      disk.iostat = {
        graph_title = "IOstat";
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
      };
      disk.iostat_ios = {
        graph_title = "IO Service time";
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
      };
      disk.smart_ = {
        graph_title = "S.M.A.R.T values for drive \${smart_device}";
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
      };
      network.if_ = {
        graph_title = "\${interface} traffic";
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
      };
      network.if_err_ = {
        graph_title = "\${interface} errors";
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
      };
      network.netstat = {
        graph_title = "Netstat";
        graph_vlabel = "TCP connection rate";
        graph_info = "This graph shows the TCP activity of all the network interfaces combined.";
        graph_args.logarithmic = true;
        influx = [
          {
            imports = ["regexp" "strings"];
            filter._measurement = ["net" "nstat"];
            filter._field = let
              fields = ["ActiveOpens" "PassiveOpens" "AttemptFails" "EstabResets"];
            in (map (f: "Tcp" + f) fields) ++ (map (f: "tcp_" + (lib.toLower f)) fields);
            fn = null;
            groupBy = [
              { expr = ''
                  |> map(fn: (r) => ({
                    r with
                      _measurement: "net",
                      _field: regexp.replaceAllString(
                        r: /^tcp_?/, t: "",
                        v: strings.toLower(v: r._field),
                      ),
                  }))
                ''; }
              { fn = "derivative"; fields = ["host"]; }
            ];
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
      };
      # http_loadtime
      # fw_packets
      # graph_category postfix
      # graph_category processes
      processes.forks = {
        graph_title = "Fork rate";
        graph_info = "This graph shows the number of forks (new processes started) per second.";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "kernel";
        influx.filter._field = "processes_forked";
        influx.fn = "derivative";
        unit = "hertz";
      };
      processes.processes = {
        graph_title = "Processes";
        graph_info = "This graph shows the number of processes";
        graph_args.lower-limit = 0;
        stacking = true;
        influx.filter._measurement = "processes";
        influx.filter._field = { op = "!="; values = ["total" "total_threads"]; };
        influx.fn = "mean";
        unit = "short";
      };
      # proc_pri
      processes.threads = {
        graph_title = "Number of threads";
        graph_vlabel = "number of threads";
        graph_info = "This graph shows the number of threads.";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "processes";
        influx.filter._field = "total_threads";
        influx.fn = "mean";
        unit = "short";
      };
      processes.vmstat = {
        graph_title = "VMstat";
        graph_vlabel = "process states";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "processes";
        influx.filter._field = ["blocked" "running"];
        influx.fn = "mean";
        unit = "short";
      };
      # graph_category sensors
      # acpi
      sensors.battery_capacity_ = {
        graph_title = "\${battery} capacity";
        influx.filter._measurement = "power_supply";
        influx.filter._field = [
          "charge_full_design"
          "charge_full"
          "charge_now"
        ];
        influx.filter.device = "\${battery}";
        influx.fn = "mean";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: r._value / 1000000.}))
        '';
        unit = "amph";
        repeat = "battery";
        fields.charge_full_design.displayName = "Design capacity";
        fields.charge_full.displayName = "Last full capacity";
        fields.charge_now.displayName = "Full charge";
      };
      sensors.battery_voltage_ = {
        graph_title = "\${battery} voltage";
        influx.filter._measurement = "power_supply";
        influx.filter._field = [
          "voltage_min_design"
          "voltage_now"
        ];
        influx.filter.device = "\${battery}";
        influx.fn = "mean";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: r._value / 1000000.}))
        '';
        unit = "volt";
        repeat = "battery";
        fields.voltage_min_design.displayName = "Design voltage";
        fields.voltage_now.displayName = "Present voltage";
      };
      sensors.battery_current_ = {
        graph_title = "\${battery} current";
        influx.filter._measurement = "power_supply";
        influx.filter._field = [
          "current_now"
        ];
        influx.filter.device = "\${battery}";
        influx.fn = "mean";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: r._value / 1000000.}))
        '';
        unit = "amp";
        repeat = "battery";
        fields.current_now.displayName = "Present rate";
      };
      sensors.hddtemp_smartctl = {
        graph_title = "HDD temperature";
        influx.filter._measurement = "smart_device";
        influx.filter._field = "temp_c";
        influx.fn = "mean";
        influx.extra = ''
        |> drop(columns: ["capacity", "enabled"])
      '';
        unit = "celsius";
      };
      # (new) temp_gopsutil
      sensors.sensors_fan = {
        graph_title = "Fans";
        influx.filter._measurement = "sensors";
        influx.filter._field = "fan_input";
        influx.fn = "mean";
        unit = "rotrpm";
      };
      sensors.sensors_temp = {
        graph_title = "Temperatures";
        influx.filter._measurement = "sensors";
        influx.filter._field = "temp_input";
        influx.fn = "mean";
        unit = "celsius";
      };
      sensors.sensors_volt = {
        graph_title = "Voltages";
        influx.filter._measurement = "sensors";
        influx.filter._field = "in_input";
        influx.fn = "mean";
        unit = "volt";
        graph_args.logarithmic = true;
      };
      sensors.sensors_power = {
        graph_title = "Power";
        influx.filter._measurement = "sensors";
        influx.filter._field = ["power_average"];
        influx.fn = "mean";
        unit = "watt";
      };
      # graph_category system
      system.cpu = {
        graph_title = "CPU usage";
        graph_info = "This graph shows how CPU time is spent.";
        influx.filter._measurement = "cpu";
        influx.filter._field = { op = "=~"; values = "^time"; };
        influx.fn = "derivative";
        influx.imports = ["strings"];
        influx.extra = ''
          |> group(columns: ["_measurement", "_field", "_time"])
          |> sum()
          |> group(columns: ["_measurement", "_field"])
          |> map(fn: (r) => ({r with _field: strings.trimPrefix(v: r._field, prefix: "time_")}))
          |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
        '';
        stacking = true;
        unit = "percentunit";
        fields.idle.color.mode = "fixed";
        fields.system.color = { mode = "fixed"; fixedColor = "green"; };
        fields.user.color = { mode = "fixed"; fixedColor = "blue"; };
        fields.nice.color = { mode = "fixed"; fixedColor = "orange"; };
        fieldOrder = [
          "irq"
          "softirq"
          "system"
          "user"
          "guest"
          "guest_nice"
          "nice"
          "iowait"
          "idle"
          "steal"
        ];
      };
      system.cpuspeed = {
        graph_title = "CPU frequency scaling";
        unit = "MHz";
        influx.filter._measurement = "amdgpu";
        influx.filter._field = ["current_coreclk_sum" "current_coreclk_count"];
        influx.fn = "derivative";
        influx.pivot = true;
        influx.extra = ''
          |> drop(columns: ["class", "p", "r", "slot", "subsystem_name", "subsystem_vendor_name", "device_name", "vendor_name"])
          |> map(fn: (r) => ({r with _value: r.current_coreclk_sum/r.current_coreclk_count}))
          |> drop(columns: ["current_coreclk_sum", "current_coreclk_count"])
          |> filter(fn: (r) => (r._value < 65000.)) // sometimes 65535 is reported instead of a real value
        '';
      };
      # cpuspeed
      system.entropy = {
        graph_title = "Available entropy";
        graph_info = "This graph shows the amount of entropy available in the system.";
        influx.filter._measurement = "kernel";
        influx.filter._field = "entropy_avail";
        influx.fn = "mean";
      };
      system.interrupts = {
        graph_title = "Interrupts and context switches";
        graph_info = "This graph shows the number of interrupts and context switches on the system. These are typically high on a busy system.";
        graph_vlabel = "interrupts & ctx switches";
        influx.filter._measurement = "kernel";
        influx.filter._field = ["context_switches" "interrupts"];
        influx.fn = "derivative";
        unit = "hertz";
      };
      system.irqstats = {
        graph_title = "Individual interrupts";
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
      };
      system.load = {
        graph_title = "Load average (1m)";
        graph_info = ''The load average of the machine describes how many processes are in the run-queue (scheduled to run "immediately").'';
        graph_vlabel = "load";
        influx.filter._measurement = "system";
        influx.filter._field = "load1";
        influx.fn = "mean";
        unit = "short";
      };
      system.memory = {
        graph_title = "Memory usage";
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
        panel.fieldConfig.defaults = {
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
      };
      system.open_files = {
        graph_title = "File table usage";
        graph_info = "This graph monitors the Linux open files table.";
        graph_vlabel = "number of open files";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "linux_sysctl_fs";
        influx.filter._field = "file-nr";
        influx.fn = "mean";
        unit = "short";
      };
      system.open_inodes = {
        graph_title = "Inode table usage";
        graph_info = "This graph monitors the Linux open inode table.";
        graph_vlabel = "number of open inodes";
        influx.filter._measurement = "linux_sysctl_fs";
        influx.filter._field = ["inode-nr" "inode-free-nr"];
        influx.fn = "mean";
        influx.pivot = true;
        influx.extra = ''
        |> map(fn: (r) => ({_time: r._time, host: r.host, "inode table size": r["inode-nr"], "open inodes": r["inode-nr"]-r["inode-free-nr"]}))
      '';
        unit = "short";
      };
      system.swap = {
        graph_title = "Swap in/out";
        graph_vlabel = "in (-) / out (+)";
        influx.filter._measurement = "swap";
        influx.filter._field = ["in" "out"];
        influx.fn = "derivative";
        fields."in".custom.transform = "negative-Y";
        unit = "binBps";
      };
      system.uptime = {
        graph_title = "Uptime";
        influx.filter._measurement = "system";
        influx.filter._field = "uptime";
        influx.fn = "mean";
        unit = "s";
      };
      system.users = {
        # TODO: Break down by tty/pty/pts/X/other
        graph_title = "Logged in users";
        influx.filter._measurement = "system";
        influx.filter._field = "n_users";
        influx.fn = "mean";
        unit = "short";
      };
      systemd.ip_traffic_bytes = {
        panel.interval = "60s";
        graph_title = "Unit IP traffic";
        graph_vlabel = "bits in (-) / out (+) per second";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = ["IPIngressBytes" "IPEgressBytes"];
        influx.fn = "derivative";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: 8. * r._value}))
        '';
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.ControlGroup} \${__field.labels.host}";
        };
        fields.IPIngressBytes.custom.transform = "negative-Y";
        unit = "bps";
      };
      systemd.ip_traffic_packets = {
        panel.interval = "60s";
        graph_title = "Unit IP packets";
        graph_vlabel = "packets in (-) / out (+) per second";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = ["IPIngressPackets" "IPEgressPackets"];
        influx.fn = "derivative";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.ControlGroup} \${__field.labels.host}";
        };
        fields.IPIngressPackets.custom.transform = "negative-Y";
        unit = "pps";
        right = true;
      };
      systemd.io_bytes = {
        panel.interval = "60s";
        graph_title = "Unit IO throughput";
        graph_vlabel = "Bytes/second read (-) / write (+)";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = ["IOReadBytes" "IOWriteBytes"];
        influx.fn = "derivative";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.ControlGroup} \${__field.labels.host}";
        };
        fields.IOReadBytes.custom.transform = "negative-Y";
        unit = "binBps";
      };
      systemd.io_packets = {
        panel.interval = "60s";
        graph_title = "Unit IOs";
        graph_vlabel = "IOs/second read (-) / write (+)";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = ["IOReadOperations" "IOWriteOperations"];
        influx.fn = "derivative";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.ControlGroup} \${__field.labels.host}";
        };
        fields.IOReadOperations.custom.transform = "negative-Y";
        unit = "iops";
        right = true;
      };
      systemd.cpu = {
        panel.interval = "60s";
        graph_title = "Unit CPU usage";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = "CPUUsageNSec";
        influx.filter.unit_type = { op = "!="; values = "slice"; };
        influx.fn = "derivative";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: r._value / 1000000000.}))
        '';
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.Id} \${__field.labels.host}";
        };
        stacking = true;
        unit = "percentunit";
      };
      systemd.memory = {
        panel.interval = "60s";
        graph_title = "Unit memory usage";
        influx.filter._field = "MemoryCurrent";
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.ControlGroup} \${__field.labels.host}";
        };
        unit = "bytes";
      };
      # postgres_autovacuum
      db.postgres_bgwriter = {
        graph_title = "PostgreSQL bgwriter";
        graph_vlabel = "buffers per second";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "postgresql";
        influx.filter._field = [
          "buffers_checkpoint"
          "buffers_clean"
          "buffers_backend"
          "buffers_alloc"
        ];
        influx.fn = "derivative";
        fields.buffers_checkpoint.displayName = "Buffers at checkpoint";
        fields.buffers_clean.displayName = "Buffers cleaned";
        fields.buffers_backend.displayName = "Buffers by backend";
        fields.buffers_alloc.displayName = "Buffers allocated";
      };
      db.postgres_cache_ = {
        graph_title = "PostgreSQL buffer cache";
        graph_vlabel = "buffers per second";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "postgresql";
        influx.filter._field = [
          "blks_read"
          "blks_hit"
        ];
        influx.fn = "derivative";
        unit = "rps";
      };
      db.postgres_checkpoints = {
        graph_title = "PostgreSQL checkpoints";
        graph_vlabel = "checkpoints per second";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "postgresql";
        influx.filter._field = [
          "checkpoints_timed"
          "checkpoints_req"
        ];
        influx.fn = "derivative";
        fields.checkpoints_timed.displayName = "Timed checkpoints";
        fields.checkpoints_req.displayName = "Requested checkpoints";
        unit = "reqps";
      };
      # postgres_checksums
      # postgres_connections_
      db.postgres_connections_db = {
        graph_title = "PostgreSQL connections per database";
        graph_vlabel = "connections";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "postgresql";
        influx.filter._field = "session_time";
        influx.fn = "derivative";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: r._value / 1000.}))
        '';
      };
      # postgres_locks_
      # postgres_oldest_prepared_xact_
      # postgres_prepared_xacts_
      # postgres_querylength_
      # postgres_scans_
      # postgres_size_
      # postgres_streaming_
      db.postgres_transactions_ = {
        graph_title = "PostgreSQL transactions";
        graph_vlabel = "transactions per second";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "postgresql";
        influx.filter._field = [
          "xact_commit"
          "xact_rollback"
        ];
        influx.fn = "derivative";
        unit = "ops";
      };
      db.postgres_tuples_ = {
        graph_title = "PostgreSQL tuple access";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "postgresql";
        influx.filter._field = [
          "tup_deleted"
          "tup_fetched"
          "tup_inserted"
          "tup_returned"
          "tup_updated"
        ];
        influx.fn = "derivative";
        unit = "rowsps";
      };
      # postgres_users
      # postgres_xlog
      fs.zfs_arcstats_size = {
        graph_title = "ZFS ARC - Size";
        graph_args.lower-limit = 0;
        influx.filter._measurement = "zfs";
        influx.filter._field = [
          # Stacked area
          "arcstats_data_size"
          "arcstats_metadata_size"
          "arcstats_hdr_size"
          "arcstats_dbuf_size"
          "arcstats_dnode_size"
          "arcstats_bonus_size"
          # Lines
          "arcstats_mru_size"
          "arcstats_mfu_size"
          "arcstats_size"
          "arcstats_c"
          "arcstats_p"
        ];
        influx.fn = "mean";
        influx.imports = ["strings"];
        influx.extra = ''
          |> map(fn: (r) => ({r with _field: strings.trimPrefix(prefix: "arcstats_", v: r._field)}))
        '';
        stacking = true;
        panel.fieldConfig.defaults = {
          custom.fillOpacity = 50;
        };
        unit = "bytes";
        fields = lib.recursiveUpdate (lib.genAttrs [
          "mru_size"
          "mfu_size"
          "size"
          "c"
          "p"
        ] (_: {
          custom.lineWidth = 2;
          custom.fillOpacity = 0;
          custom.stacking.mode = "none";
        })) {
          c.displayName = "Target size";
          p.displayName = "Target MRU size";
        };
      };
      fs.zfs_arcstats_activity = {
        graph_title = "ZFS ARC - Activites";
        graph_vlabel = "misses (-) / hits (+)";
        influx.filter._measurement = "zfs";
        influx.filter._field = [
          "arcstats_hits"
          "arcstats_misses"
          "arcstats_l2_hits"
          "arcstats_l2_misses"
        ];
        influx.fn = "derivative";
        unit = "iops";
        fields.arcstats_hits.displayName = "ARC hits";
        fields.arcstats_misses = {
          displayName = "ARC misses";
          custom.transform = "negative-Y";
        };
        fields.arcstats_l2_hits.displayName = "L2ARC hits";
        fields.arcstats_l2_misses = {
          displayName = "L2ARC misses";
          custom.transform = "negative-Y";
        };
      };
      fs.zpool_iostat = {
        graph_title = "zpool iostat";
        graph_vlabel = "read (-) / written (+)";
        graph_info = "This graph shows zpool iostat";
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["read_bytes" "write_bytes"];
        influx.fn = "derivative";
        fields.read_bytes.custom.transform = "negative-Y";
        unit = "Bps";
      };
    };
  };
}
