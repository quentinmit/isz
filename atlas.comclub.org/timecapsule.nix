{ config, ... }:
{
  services.netatalk = {
    enable = true;
    settings = {
      Global."uam list" = "uams_dhx.so uams_dhx2.so uams_dhx2_password.so";
      Global."afp listen" = "192.168.0.254";
      Homes = {
        "basedir regex" = "/home";
      };
      TimeCapsule = {
        path = "/var/lib/timecapsule";
        "time machine" = "yes";
        "valid users" = "ginas";
      };
    };
  };
  # TODO: Switch to samba
  # https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
  # https://www.samba.org/samba/docs/current/man-html/vfs_fruit.8.html
}
