{ config, pkgs, lib, nixpkgs, disko, nixos-hardware, ... }:
{
  imports = [
    nixos-hardware.nixosModules.framework-16-7040-amd
    ./disko.nix
    disko.nixosModules.disko
    ./quentin.nix
    ./opensnitch.nix
  ];
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      openssh = final.openssh_gssapi.override {
        dsaKeysSupport = true;
      };
    })
  ];
  nixpkgs.config.permittedInsecurePackages = [
    "python3.11-youtube-dl-2021.12.17"
    "segger-jlink-qt4-796s"
    "segger-systemview-qt4-352a"
    "olm-3.2.16"
  ];
  nixpkgs.config.segger-jlink.acceptLicense = true;

  system.stateVersion = "23.11";

  sops.defaultSopsFile = ./secrets.yaml;

  time.timeZone = lib.mkForce null;

  networking.hostName = "goddard";

  isz.secureBoot.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [''dyndbg="file drivers/base/firmware_loader/main.c +fmp"''];

  environment.etc."lvm/lvm.conf".text = ''
    devices/issue_discards=1
  '';
  services.fstrim.enable = true;
  services.smartd.enable = true;

  services.fwupd.enable = true;

  hardware.framework.enableKmod = false;

  # Only use fingerprint for the kde-fingerprint PAM service.
  security.pam.services.kde.fprintAuth = false;
  security.pam.services.kde-fingerprint = {
    unixAuth = false;
    rules.auth.fprintd.settings = {
      max-tries = 10;
      debug = true;
      timeout = 3600;
    };
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.package = if (lib.versionOlder pkgs.bluez.version "5.76") then pkgs.unstable.bluez else pkgs.bluez;

  hardware.keyboard.qmk.enable = true;

  networking.networkmanager.enable = true;

  services.firewalld = {
    enable = true;
    package = pkgs.firewalld-gui;
    config = {
      DefaultZone = "public";
      FirewallBackend = "nftables";
    };
  };

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

  programs.gnupg.agent.enable = true;

  isz.pipewire.enable = true;

  # TODO: EQ profile
  # https://gist.github.com/cab404/aeb2482e1af6fc463e1154017c566560/
  # https://github.com/cab404/framework-dsp/

  services.hardware.bolt.enable = true;

  isz.gpu.enable = true;
  isz.gpu.amd = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "armv6l-linux"
  ];
  boot.binfmt.registrations = {
    armeb = let
      qemu = "${pkgs.qemu-user}/bin/qemu-armeb";
      wrapperName = "qemu-armeb-binfmt-P";
      wrapper = pkgs.wrapQemuBinfmtP wrapperName qemu;
      interpreter = "${wrapper}/bin/${wrapperName}";
    in {
      preserveArgvZero = true;
      inherit interpreter;
      fixBinary = false;
      wrapInterpreterInShell = false;
      interpreterSandboxPath = "${wrapper}";

      magicOrExtension = ''\x7fELF\x01\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28'';
      mask = ''\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff'';
    };
  };

  environment.systemPackages = with pkgs; [
    # Virtualisation
    vde2

    # KDE
    kdePackages.plasma-firewall
    kdePackages.plasma-thunderbolt
    kio-fuse

    # Thunderbolt
    thunderbolt

    # Framework
    framework-tool
    fw-ectool
    qmk_hid
    openrgb-with-all-plugins
    wd-fw-update

    # Networking
    iw

    # Laptop
    powertop

    # Radio
    limesuiteWithGui

    scowl

    # Development
    segger-jlink
    segger-ozone
    segger-systemview
  ];

  services.udev.packages = with pkgs; [
    platformio-core.udev
    limesuiteWithGui
  ];

  services.nixseparatedebuginfod.enable = true;

  # TODO(libinput > 1.25.0): Remove
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Framework Laptop 16 Keyboard Module]
    MatchName=Framework Laptop 16 Keyboard Module*
    MatchUdevType=keyboard
    MatchDMIModalias=dmi:*svnFramework:pnLaptop16*
    AttrKeyboardIntegration=internal
  '';

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.xserver.windowManager.twm.enable = true;
  services.desktopManager.plasma6.enable = true;
  programs.kdeconnect.enable = true;

  fonts.fontDir.enable = true;
  fonts.fontconfig.subpixel.rgba = "rgb";
  fonts.packages = with pkgs; [
    corefonts
  ];

  environment.etc."xdg/Xwayland-session.d/10-nixos.sh".source = let
    fontDir = builtins.elemAt (lib.strings.split "\"" config.services.xserver.filesSection) 2;
  in pkgs.writeShellScript "xwayland-session-nixos" ''
    ${pkgs.xorg.xset}/bin/xset +fp ${fontDir},${pkgs.xorg.fontadobe100dpi}/lib/X11/fonts/100dpi
  '';

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.xdgOpenUsePortal = true;
  # TODO: Enable KDE portal?

  programs.chromium = {
    enable = true;
    enablePlasmaBrowserIntegration = true;
  };

  programs.steam.enable = true;

  programs.wireshark.package = pkgs.wireshark;

  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
  };

  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.podman = {
    enable = true;
  };
  virtualisation.containers.containersConf.settings = {
    network.firewall_driver = "none"; # firewalld
  };

  virtualisation.waydroid.enable = true;

  # TODO: Switch to systemd-resolved for mDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  isz.krb5.enable = true;

  nix.settings = {
    trusted-users = [ "root" "quentin" ];
  };

  environment.wordlist = {
    enable = true;
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
      "podman"
      "audio"
    ];
  };
}
