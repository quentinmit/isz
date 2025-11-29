{ config, pkgs, disko, lib, modulesPath, nixos-hardware, ... }:
{
  imports = [
    ./disko.nix
    disko.nixosModules.disko
    ./networking.nix
    ./libvirt.nix
    ./users.nix
    ./dovecot.nix
    ./nginx.nix
    ./home-assistant.nix
    ./apcupsd.nix
    ./postfix.nix
    ./ddclient.nix
    ./timecapsule.nix
    "${nixos-hardware}/common/cpu/intel/coffee-lake"
  ];

  nixpkgs.hostPlatform = { system = "x86_64-linux"; };

  sops.defaultSopsFile = ./secrets.yaml;

  virtualisation = let
    vmVariant = {
      users.users.root.hashedPassword = "";
      boot.initrd.systemd.emergencyAccess = true;
      services.locate.enable = lib.mkForce false;
    };
  in {
    inherit vmVariant;
    vmVariantWithDisko = vmVariant // {
      disko.devices.zpool.zpool = {
        rootFsOptions.keylocation = "file:///tmp/secret.key";
        preCreateHook = "echo 'secretsecret' > /tmp/secret.key";
        postCreateHook = "zfs set keylocation=prompt zpool";
      };
    };
  };

  isz.secureBoot.enable = true;
  boot.lanzaboote.pkiBundle = lib.mkForce "/var/lib/sbctl";

  boot = {
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

    extraModulePackages = [((pkgs.callPackage ../nix/kernel-module.nix {
      inherit (config.boot.kernelPackages) kernel;
      modulePath = "drivers/edac";
    }).overrideAttrs {
      patches = [
        ./linux-edac.patch
      ];
    })];
  };

  boot.initrd.clevis = {
    enable = true;
    # Don't use in VM builds
    devices.zpool = lib.mkIf config.boot.zfs.enabled {
      secretFile = "${./zpool.jwe}";
    };
  };

  networking.hostName = "atlas";
  networking.domain = "comclub.org";
  networking.hostId = "b28d99fc";

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519"];
    #useSops = true;
  };

  services.openssh = {
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    extraConfig = ''
      Match Address 192.168.0.0/24
        PasswordAuthentication yes
        KbdInteractiveAuthentication yes
    '';
  };

  hardware.rasdaemon.enable = true;

  boot.swraid.mdadmConf = ''
    MAILADDR root@comclub.org
  '';

  system.stateVersion = "25.05";

  users.users.root = {};
}
