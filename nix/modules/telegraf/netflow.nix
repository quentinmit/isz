{ lib, config, ... }:
let
  cfg = config.isz.telegraf.netflow;
  period = config.isz.telegraf.interval.netflow;
in {
  options = with lib; {
    isz.telegraf.netflow = {
      enable = mkEnableOption "Capture Netflow data";
    };
  };
  config = lib.mkIf cfg.enable {
    isz.telegraf.interval.netflow = lib.mkOptionDefault "60s";
    services.telegraf.extraConfig = {
      inputs.netflow = [{
        name_suffix = "_raw";
        tags.influxdb_bucket = "netflow_raw";
        service_address = "udp://:2055";
        protocol = "ipfix";
      }];
      processors.converter = [{
        namepass = ["netflow_raw"];
        order = 10;
        fields.tag = [
          "in_snmp" # interface index
          "out_snmp" # interface index
          "in_src_mac"
          "in_dst_mac"
          "out_src_mac"
          "out_dst_mac"
          "ip_version"
          "protocol"
          "src"
          "dst"
          "src_port"
          "dst_port"
          "xlat_src"
          "xlat_src_port"
          "xlat_dst"
          "xlat_dst_port"
          "src_mask"
          "dst_mask"
          "icmp_type"
          "icmp_code"
          "igmp_type"
          "mcast"
          "next_hop"
          "src_tos"
          "dst_tos"
        ];
      }];
      processors.ifname = map (prefix: {
        namepass = ["netflow_raw"];
        tagdrop."${prefix}_snmp" = ["0"]; # Don't try to give a name to 0, which represents the host.
        order = 20;
        agent = "source";
        tag = "${prefix}_snmp";
        dest = "${prefix}_interface";
      }) ["in" "out"];
#       processors.filter = [{ # XXX: for debugging, only keep one device's data
#         order = 100; # after everything else
#         namepass = ["netflow_*"];
#         default = "drop";
#         rule = builtins.map (name: {
#           tags.${name} = ["172.30.96.104"];
#           action = "pass";
#         }) ["src" "dst" "xlat_src" "xlat_dst"];
#       }];
      processors.regex = [{
        namepass = ["netflow_mac"];
        field_rename = [{
          pattern = "^(.+)_sum$";
          replacement = "\${1}";
        }];
      }];
      processors.override = [{
        namepass = ["netflow_*"];
        namedrop = ["netflow_raw"];
        tags.influxdb_bucket = "netflow";
      }];

      aggregators.basicstats = [{
        namepass = ["netflow_raw"];
        name_override = "netflow_mac";
        inherit period;
        drop_original = false;
        taginclude = [
          "host"
          "influxdb_bucket"
          "source"

          "in_snmp"
          "out_snmp"
          "in_interface"
          "out_interface"
          "in_src_mac"
          "in_dst_mac"
          "out_src_mac"
          "out_dst_mac"
          "ip_version"
          "protocol"
        ];
        fieldinclude = ["in_packets" "in_bytes"];
        stats = ["sum"];
      }];
    };
  };
}
