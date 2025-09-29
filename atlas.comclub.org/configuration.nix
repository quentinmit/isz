{ config, pkgs, disko, lib, modulesPath, ... }:
{
  imports = [
    ./disko.nix
    disko.nixosModules.disko
    ./networking.nix
    ./libvirt.nix
    ./users.nix
    ./dovecot.nix
    ./nginx.nix
    # home-assistant
    # apcupsd
    # postfix
    # postgrey
    # amavisd
    # named
    # dhcp
  ];

  nixpkgs.hostPlatform = { system = "x86_64-linux"; };

  sops.defaultSopsFile = ./secrets.yaml;

  virtualisation = let
    qemu-common = import "${modulesPath}/../lib/qemu-common.nix" { inherit lib pkgs; };
    interfaces = [{
      name = "enp2s0";
      vlan = 2;
    }];
    interfacesNumbered = lib.zipLists interfaces (lib.range 1 255);
    qemuOptions = lib.flatten (
      lib.forEach interfacesNumbered (
        { fst, snd }: [(lib.head (qemu-common.qemuNICFlags snd fst.vlan 1)) "-netdev hubport,id=vlan${toString snd},hubid=${toString snd}"]
      )
    );
    udevRules = lib.forEach interfacesNumbered (
      { fst, snd }:
      # MAC Addresses for QEMU network devices are lowercase, and udev string comparison is case-sensitive.
      ''SUBSYSTEM=="net",ACTION=="add",ATTR{address}=="${lib.toLower (qemu-common.qemuNicMac fst.vlan 1)}",NAME="${fst.name}"''
    );
    vmVariant = {
      users.users.root.hashedPassword = "";
      boot.initrd.systemd.emergencyAccess = true;
    };
  in {
    inherit vmVariant;
    vmVariantWithDisko = vmVariant // {
      disko.devices.zpool.zpool = {
        rootFsOptions.keylocation = "file:///tmp/secret.key";
        preCreateHook = "echo 'secretsecret' > /tmp/secret.key";
        postCreateHook = "zfs set keylocation=prompt zpool";
      };
      virtualisation.qemu.options = qemuOptions;
      boot.initrd.services.udev.rules = lib.concatMapStrings (x: x + "\n") udevRules;
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
