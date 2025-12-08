{ config, lib, ... }:
let
  cfg = config.isz.syncoid;
in {
  options = {
    isz.syncoid = {
      enable = lib.mkEnableOption "Syncoid backups";
    };
  };
  config = lib.mkIf cfg.enable {
    services.zfs.autoSnapshot.enable = false;
    services.sanoid = {
      enable = true;
      interval = "*:0/15";
      templates.default = {
        frequently = 4;
        hourly = 24;
        daily = 7;
        monthly = 12;
        yearly = 0;
      };
      datasets = lib.mapAttrs (_: _: {
        use_template = ["default"];
        recursive = "zfs";
      }) config.disko.devices.zpool;
    };
    sops.secrets."syncoid/ssh_keys/heartofgold" = {
      owner = config.services.syncoid.user;
    };
    services.syncoid = {
      enable = true;
      interval = "0/3:10"; # Every 3 hours at :10 after the hour
      localSourceAllow = [
        "bookmark"
        "hold"
        "release"
        "send"
        "snapshot"
        "destroy"
        "mount"
      ];
      commands = lib.mapAttrs' (name: _: lib.nameValuePair "${name}-heartofgold" {
        extraArgs = [
          "--debug"
          "--no-sync-snap"
          "--use-hold"
          "--create-bookmark"
          #"--force-delete"
        ];
        sendOptions = "Rw X ${name}/nix";
        recvOptions = "v u o canmount=off o secondarycache=none o mountpoint=/srv/backup/${config.networking.hostName}/${name} o com.sun:auto-snapshot=false o readonly=on";
        source = name;
        target = "syncoid-${config.networking.hostName}@heartofgold.mgmt.isz.wtf:zpool/backup/${config.networking.hostName}/${name}";
        sshKey = config.sops.secrets."syncoid/ssh_keys/heartofgold".path;
      }) config.disko.devices.zpool;
    };
  };
}
