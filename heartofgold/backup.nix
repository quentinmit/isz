{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    mbuffer
  ];
  users.groups.syncoid-targets = {};
  users.users."syncoid-workshop" = {
    isSystemUser = true;
    group = "syncoid-targets";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJp0JhnfZevlSxn5DSVOaybntyM1OkNLKOzZi50yL+yX"
    ];
  };
}
