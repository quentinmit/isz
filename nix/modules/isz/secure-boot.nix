{ config, lib, pkgs, lanzaboote, ... }:
{
  imports = [
    lanzaboote.nixosModules.lanzaboote
  ];
  options = with lib; {
    isz.secureBoot.enable = mkEnableOption "secure boot";
  };
  config = lib.mkIf config.isz.secureBoot.enable {
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot = {
      enable = lib.mkForce false;
      memtest86.enable = true;
    };
    boot.initrd.systemd.enable = true;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    environment.systemPackages = with pkgs; [
      efitools
      sbctl
      sbsigntool
      tpm2-tools
    ];
  };
}
