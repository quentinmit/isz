{ config, pkgs, lib, ... }:
let
  transmissionUid = 901;
in {
  containers.rtorrent = {
    bindMounts."/srv/media/media1e" = {
      hostPath = "/srv/media/media1e";
      mountPoint = "/srv/media/media1e";
      isReadOnly = false;
    };
    config = { config, pkgs, lib, ... }: {
      services.transmission = {
        enable = true;
        package = pkgs.transmission_4;
        group = "users";
        settings = {
          rpc-bind-address = "unix:/var/lib/transmission/rpc.sock";
          umask = "002";
          download-dir = "/srv/media/media1e/Torrents";
          incomplete-dir = "/srv/media/media1e/Torrents/.incomplete";
          speed-limit-up = 250;
          speed-limit-up-enabled = true;
          port-forwarding-enabled = false;
          peer-port-random-on-start = true;
          message-level = 4; # 4 = info, 5 = debug
          preallocation = 0; # No point on ZFS
        };
      };
      systemd.services.transmission.serviceConfig = {
        BindPaths = lib.mkForce [
          "${config.services.transmission.home}/.config/transmission-daemon"
          config.services.transmission.settings.download-dir
          "/run/nscd"
          "/run/systemd/resolve"
        ];
        RestrictAddressFamilies = lib.mkForce ["AF_UNIX" "AF_INET"];
      };
    };
  };
  boot.kernel.sysctl."net.core.rmem_max" = 4194304;
  boot.kernel.sysctl."net.core.wmem_max" = 1048576;
  systemd.sockets.transmission-proxy = {
    wantedBy = ["sockets.target"];
    listenStreams = ["9091"];
  };
  systemd.services.transmission-proxy = {
    requires = ["transmission-proxy.socket"];
    after = ["transmission-proxy.socket"];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd /var/lib/nixos-containers/rtorrent/var/lib/transmission/rpc.sock";
      PrivateTmp = "yes";
      PrivateNetwork = "yes";
    };
  };
}
