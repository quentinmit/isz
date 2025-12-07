{ config, ... }:
{
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
    datasets.zpool = {
      use_template = ["default"];
      recursive = "zfs";
    };
    datasets."zpool/nix" = {
      autosnap = false;
    };
  };
  sops.secrets."syncoid/ssh_keys/heartofgold" = {
    owner = config.services.syncoid.user;
  };
  services.syncoid = {
    enable = true;
    interval = [];
    commands."zpool-heartofgold" = {
      extraArgs = [
        "--no-sync-snap"
        "--use-hold"
        "--create-bookmark"
      ];
      sendOptions = "Rw X zpool/nix";
      recvOptions = "u";
      source = "zpool";
      target = "syncoid-workshop@heartofgold.mgmt.isz.wtf:zpool/backup/workshop";
      sshKey = config.sops.secrets."syncoid/ssh_keys/heartofgold".path;
    };
  };
}
