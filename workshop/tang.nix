{ config, lib, ... }:
{
  services.tang = {
    enable = true;
    listenStream = ["/run/tangd/tangd.sock"];
    ipAddressAllow = ["any"];
  };
  users.groups.nginx-tangd = {};
  users.users."${config.services.nginx.user}".extraGroups = ["nginx-tangd"];
  systemd.sockets.tangd = {
    socketConfig = {
      SocketGroup = "nginx-tangd";
      SocketMode = "0660";
    };
  };
  services.nginx = {
    upstreams.tangd.servers."unix:/run/tangd/tangd.sock" = {};
    virtualHosts = {
      "tang.isz.wtf" = {
        locations."/".proxyPass = "http://tangd";
        extraConfig = ''
          allow 172.30.96.0/24;
          allow 172.30.97.0/24;
          deny all;
        '';
      };
    };
  };
}
