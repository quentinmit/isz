{ lib, pkgs, ... }:
{
  config = {
    services.telegraf.extraConfig = lib.mkMerge [
      {
        inputs = {
          disk = [{
            ignore_fs = ["tmpfs" "devtmpfs" "devfs" "overlay" "aufs" "squashfs"];
          }];
          diskio = [{
            device_tags = [
              "DEVPATH"
              "ID_MODEL"
              "ID_SERIAL_SHORT"
              "ID_REVISION"
            ];
          }];
        };
      }
      (lib.mkIf pkgs.stdenv.isLinux {
        inputs.file = [{
          alias = "scsi";
          files = ["/sys/block/*/device/*_cnt"];
          name_override = "scsi";
          file_path_tag = "sysfs_path";
          data_format = "value";
          data_type = "string";
        }];
        processors.starlark = [{
          alias = "scsi";
          namepass = ["scsi"];
          source = ''
            def apply(metric):
              parts = metric.tags.pop("sysfs_path").split("/")
              name = parts[3]
              field = parts[5]
              metric.tags["name"] = name
              metric.fields[field] = int(metric.fields.pop("value"), 0)
              return [metric]
          '';
        }];
      })
    ];
  };
}
