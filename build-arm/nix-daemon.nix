{ lib, pkgs, config, ... }:
{
  sops.secrets."nix/secret-key" = {};
  nix.settings.secret-key-files = [
    config.sops.secrets."nix/secret-key".path
  ];
  nix.settings.extra-platforms = [
    "armv7l-linux"
    "armv8l-linux"
  ];
  users.users.goddard = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHhaNWmnfCIb5PHhBWQQXBp5YTV4QRFfGNhDpFh8Yrv2 nix@goddard"
    ];
  };
}
