{ config, pkgs, lib, ... }:
{
  imports = [
    ../../nix/modules/vmspawn/vmconfig.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      openssh = final.openssh_gssapi;
    })
  ];

  system.name = "goddard-afs";
  system.stateVersion = "25.05";
  isz.krb5.enable = true;
  services.openafsClient = {
    enable = true;
    cellName = "athena.mit.edu";
  };
  nix.settings.trusted-users = [ "root" "quentin" ];
  virtualisation.vmVariant = {
    users.users.root.hashedPassword = "";
    users.users.quentin.hashedPassword = "";
    boot.initrd.systemd.emergencyAccess = true;
    services.locate.enable = lib.mkForce false;
  };
  users.users.quentin = {
    isNormalUser = true;
    uid = 24424;
    description = "Quentin Smith";
    extraGroups = [
      "wheel"
    ];
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "25.05";
      isz.quentin.enable = true;
    }
  ];
}
