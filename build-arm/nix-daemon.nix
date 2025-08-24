{ lib, pkgs, ... }:
{
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
