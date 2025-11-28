{ config, pkgs, lib, disko, nixos-hardware, ... }:
{
  imports = [
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-cpu-amd-pstate
    nixos-hardware.nixosModules.common-cpu-amd-zenpower
    nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    nixos-hardware.nixosModules.common-gpu-amd
    ./disko.nix
    ./quentin.nix
    ./openvpn
    ./jellyfin.nix
    ./containers.nix
    ./bitmagnet
    disko.nixosModules.disko
  ];
  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "24.05";

  sops.defaultSopsFile = ./secrets.yaml;

  networking.hostName = "heartofgold";
  networking.hostId = "8daa50bc";

  boot.initrd.systemd.enable = true;
  boot.zfs.requestEncryptionCredentials = ["zpool"];
  boot.kernelModules = [
    "nct6775" # For sensors
  ];

  # nvme nvme0: controller is down; will reset: CSTS=0xffffffff, PCI_STATUS=0xffff
  # nvme nvme0: Does your device have a faulty power saving mode enabled?
  # nvme nvme0: Try "nvme_core.default_ps_max_latency_us=0 pcie_aspm=off pcie_port_pm=off" and report a bug
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
    "pcie_port_pm=off"
  ];

  boot.loader.systemd-boot.memtest86.enable = true;
#   boot.loader.grub.enable = false;
#   boot.loader.systemd-boot.enable = true;
  isz.secureBoot.enable = true;
  boot.initrd.clevis = {
    enable = true;
    devices.zpool.secretFile = "${./zpool.jwe}";
  };

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  isz.networking = {
    lastOctet = 101;
    macAddress = "E8:9C:25:6B:1E:B9";
    vlan88 = true;
  };

  networking.firewall.enable = false;
  networking.networkmanager.enable = false;

  services.smartd.enable = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;

  hardware.rasdaemon.enable = true;

  isz.telegraf = {
    enable = true;
    intelRapl = true;
    amdgpu = true;
    powerSupply = true;
    drm = true;
  };

  isz.vector = {
    enable = true;
  };

  security.polkit.enable = true;
  environment.etc."polkit-1/rules.d/15-logind.rules".text = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.power-off" ||
          action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
          action.id == "org.freedesktop.login1.reboot" ||
          action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
          action.id == "org.freedesktop.login1.suspend" ||
          action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
          action.id == "org.freedesktop.login1.hibernate" ||
          action.id == "org.freedesktop.login1.hibernate-multiple-sessions" ||
          action.id == "org.freedesktop.login1.set-reboot-parameter" ||
          action.id == "org.freedesktop.login1.set-reboot-to-firmware-setup" ||
          action.id == "org.freedesktop.login1.set-reboot-to-boot-loader-menu" ||
          action.id == "org.freedesktop.login1.set-reboot-to-boot-loader-entry")
      {
          return polkit.Result.AUTH_ADMIN;
      }
    });
  '';

  isz.pipewire.enable = true;

  isz.gpu.enable = true;
  isz.gpu.amd = true;

  environment.systemPackages = with pkgs; [
    kdePackages.krfb
    kdePackages.krdc
  ];

  services.xserver.enable = true;
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };
  services.desktopManager.gnome.enable = true;
  services.xserver.windowManager.twm.enable = true;
  services.desktopManager.plasma6.enable = true;
  # Resolve conflict between GNOME and KDE
  programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass.out}/bin/ksshaskpass";
  programs.kdeconnect.enable = true;

  fonts.fontDir.enable = true;

  programs.chromium = {
    enable = true;
  };

  programs.steam.enable = true;

  programs.wireshark.package = pkgs.wireshark;

  # TODO: Switch to systemd-resolved for mDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  services.postgresql.settings.full_page_writes = false;

  isz.krb5.enable = true;

  nixpkgs.overlays = [(final: prev: {
    libblurayFull = prev.libbluray.override {
      withAACS = true;
      withBDplus = true;
      withJava = true;
    };
    vlc = prev.vlc.override {
      libbluray = final.libblurayFull;
    };
  })];

  systemd.user.services.kde-baloo = {
    # With a 20 GB index, the default memory limit of 512 MiB is just too small.
    overrideStrategy = "asDropin";
    serviceConfig.MemoryHigh = "25%";
  };

  nix.settings = {
    trusted-users = [ "root" "quentin" ];
  };

  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    extraGroups = [
      "dialout"
      "networkmanager"
      "video"
      "wheel"
      "wireshark"
      "libvirtd"
      "audio"
    ];
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };
}
