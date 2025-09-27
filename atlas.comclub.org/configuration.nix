{ config, pkgs, disko, lib, ... }:
{
  imports = [
    ./disko.nix
    disko.nixosModules.disko
  ];

  nixpkgs.hostPlatform = { system = "x86_64-linux"; };

  sops.defaultSopsFile = ./secrets.yaml;

  virtualisation.vmVariantWithDisko = {
    users.users.root.hashedPassword = "";
    boot.initrd.systemd.emergencyAccess = true;
    disko.devices.zpool.zpool = {
      rootFsOptions.keylocation = "file:///tmp/secret.key";
      preCreateHook = "echo 'secretsecret' > /tmp/secret.key";
      postCreateHook = "zfs set keylocation=prompt zpool";
    };
  };

  boot = {
    loader.grub.enable = false;
    loader.systemd-boot.enable = true;

    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "sr_mod"
    ];
    kernelModules = [ "kvm-intel" ];

    initrd.systemd.enable = true;

    consoleLogLevel = 9;
    kernelParams = [
      "rootwait"

      "consoleblank=0" # disable console blanking(screen saver)

      # container metrics
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"

      ''dyndbg="file drivers/base/firmware_loader/main.c +fmp"''
    ];
  };

  boot.initrd.clevis = {
    enable = true;
  };

  networking.hostName = "atlas";
  networking.domain = "comclub.org";
  networking.hostId = "b28d99fc";

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519"];
    #useSops = true;
  };

  system.stateVersion = "25.05";

  users.users.root = {};
}
