{ lib, ... }:
{
  # Configure home-assistant for Matter/Thread
  services.home-assistant.extraComponents = [
    "thread"
    "matter"
  ];
  # Configure matter-server
  services.matter-server = {
    enable = true;
  };
  # Configure IGMP membership limit
  # See https://github.com/matter-js/python-matter-server/blob/main/DEVELOPMENT.md#start-matter-server
  boot.kernel.sysctl."net.ipv4.igmp_max_memberships" = 1024;
}
