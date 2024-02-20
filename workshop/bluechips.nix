{ config, pkgs, lib, ... }:

{
  services.postgresql = {
    ensureDatabases = [ "bluechips" ];
    ensureUsers = [
      { name = "bluechips"; ensureDBOwnership = true; }
    ];
  };
  users.users.bluechips = {
    isSystemUser = true;
    group = "bluechips";
  };
  users.groups.bluechips = {};
  users.users."${config.services.nginx.user}".extraGroups = [ "bluechips" ];
  systemd.services.bluechips = {
    description = "BlueChips";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" "postgresql.service" ];
    after = [ "network-online.target" "postgresql.service" ];
    environment = {
      ROCKET_ADDRESS="unix:%t/bluechips/bluechips.sock";
      ROCKET_DB_URI="postgresql://?dbname=bluechips";
    };
    preStart = ''
      ${pkgs.unstable.bluechips-rs}/bin/migration up -v -u postgresql://?dbname=bluechips
    '';
    serviceConfig = {
      User = "bluechips";
      Group = "bluechips";
      RuntimeDirectory = "bluechips";
      ExecStart = "${pkgs.unstable.bluechips-rs}/bin/bluechips-rs";
      UMask = "0007";
    };
  };
  services.nginx = {
    upstreams.bluechips.servers."unix:/run/bluechips/bluechips.sock" = {};
    virtualHosts."bluechips.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://bluechips";
    };
  };
}
