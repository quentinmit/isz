{ config, lib, pkgs, disko, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    disko.nixosModules.disko
    ./disko.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "26.05";

  sops.defaultSopsFile = ./secrets.yaml;

  boot.zfs.requestEncryptionCredentials = [ "boot" ];
  boot.zfs.forceImportRoot = false;
  boot.zfs.devNodes = "/dev/disk/by-partlabel";

  boot = {
    loader.grub.enable = true;

    initrd.systemd.enable = true;
    initrd.systemd.emergencyAccess = true;
    initrd.systemd.network = config.systemd.network;
    #initrd.network.ssh.enable = true;
    initrd.network.ssh.authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "sr_mod"
      "virtio_blk"
      "virtio_net"
    ];
    kernelModules = [
      "kvm-amd"
    ];
    consoleLogLevel = 9;
    kernelParams = [
      "rootwait"
      "consoleblank=0"

      # container metrics
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];
  };

  networking.hostName = "quentin";
  networking.domain = "zfs.rent";
  networking.hostId = "e47c3be9";

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519"];
    useSops = true;
  };

  services.openssh = {
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  networking.useDHCP = true;
  networking.useNetworkd = true;
  networking.nftables.enable = true;

  virtualisation = let
    vmVariant = {
      users.users.root.hashedPassword = "";
      boot.initrd.systemd.emergencyAccess = true;
      services.locate.enable = lib.mkForce false;
    };
  in {
    inherit vmVariant;
    vmVariantWithDisko = vmVariant // {
      disko.devices.zpool.boot = {
        rootFsOptions.keylocation = "file:///tmp/secret.key";
        preCreateHook = "echo 'secretsecret' > /tmp/secret.key";
        postCreateHook = "zfs set keylocation=prompt boot";
      };
    };
  };

}
