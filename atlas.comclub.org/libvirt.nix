{ config, ... }:
{
  virtualisation.libvirtd.enable = true;
  users.users.quentin.extraGroups = ["libvirt"];
}
