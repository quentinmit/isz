{ config, pkgs, lib, nixpkgs, disko, nixos-hardware, lanzaboote, ... }:
let
  amdgpu-kernel-module = pkgs.callPackage ./amdgpu-kernel-module.nix {
    inherit (config.boot.kernelPackages) kernel;
  };
in
{
  imports = [
    #./hardware-configuration.nix
    nixos-hardware.nixosModules.framework-13-7040-amd # TODO: Switch to 16 when it exists
    ./disko.nix
    disko.nixosModules.disko
    ./quentin.nix
    ./opensnitch.nix
    lanzaboote.nixosModules.lanzaboote
  ];
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      openssh = final.openssh_gssapi;
    })
  ];

  system.stateVersion = "23.11";

  sops.defaultSopsFile = ./secrets.yaml;

  networking.hostName = "goddard";

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

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelPatches = [{
    name = "acpitz-trip_table";
    patch = ./kernel-acptiz-trip_table.patch;
  }];

  boot.extraModulePackages = lib.optional
    (config.boot.kernelPackages.kernelOlder "6.9")
    (amdgpu-kernel-module.overrideAttrs (_: {
      patches = [
        # vrr fix
        (pkgs.fetchurl {
          url = "https://gitlab.freedesktop.org/agd5f/linux/-/commit/2f14c0c8cae8e9e3b603a3f91909baba66540027.diff";
          hash = "sha256-0++twr9t4AkJXZfj0aHGMVDuOhxtLP/q2d4FGfggnww=";
        })
      ];
    }));

  environment.etc."lvm/lvm.conf".text = ''
    devices/issue_discards=1
  '';
  services.fstrim.enable = true;
  services.smartd.enable = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;

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

  security.polkit.enable = true;

  programs.gnupg.agent.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };
  # TODO: EQ profile
  # https://gist.github.com/cab404/aeb2482e1af6fc463e1154017c566560/
  # https://github.com/cab404/framework-dsp/

  services.hardware.bolt.enable = true;

  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages = with pkgs; [
    # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-amd
    rocmPackages.clr.icd
    # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-vulkan-amd
    # Disable for now (radv driver in mesa should handle)
    #amdvlk
  ];
  #hardware.opengl.extraPackages32 = with pkgs; [
  #  driversi686Linux.amdvlk
  #];

  environment.systemPackages = with pkgs; [
    libinput
    evtest
    vulkan-tools
    qmk_hid
    powertop
    power-profiles-daemon
    sbctl
    sbsigntool
    tpm2-tools
    fw-ectool
    framework-tool
    efitools
    nftables
    plasma5Packages.plasma-firewall
    plasma5Packages.plasma-thunderbolt
    thunderbolt
    glxinfo
    libva-utils
    clinfo
    nvtop-amd
    radeontop
  ];

  services.dbus.packages = with pkgs; [
    kio-fuse
  ];

  # TODO(libinput > 1.25.0): Remove
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Framework Laptop 16 Keyboard Module]
    MatchName=Framework Laptop 16 Keyboard Module*
    MatchUdevType=keyboard
    MatchDMIModalias=dmi:*svnFramework:pnLaptop16*
    AttrKeyboardIntegration=internal
  '';

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.windowManager.twm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.xdgOpenUsePortal = true;
  # TODO: Enable KDE portal?

  programs.chromium = {
    enable = true;
    # TODO(24.05): enablePlasmaBrowserIntegration = true;
  };
  environment.etc."opt/chrome/native-messaging-hosts/org.kde.plasma.browser_integration.json".source = "${pkgs.plasma5Packages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";

  programs.steam.enable = true;

  programs.wireshark.package = pkgs.wireshark;

  programs.dconf.enable = true;

  # TODO: Switch to systemd-resolved for mDNS
  services.avahi = {
    enable = true;
    nssmdns = true;
  };

  krb5.enable = true;
  krb5.libdefaults.default_realm = "ATHENA.MIT.EDU";
  krb5.realms = {
    "ATHENA.MIT.EDU" = {
      admin_server = "kerberos.mit.edu";
      default_domain = "mit.edu";
      kdc = [
        "kerberos.mit.edu:88"
        "kerberos-1.mit.edu:88"
        "kerberos-2.mit.edu:88"
      ];
    };
    "ZONE.MIT.EDU" = {
      admin_server = "casio.mit.edu";
      kdc = [
        "casio.mit.edu"
        "seiko.mit.edu"
      ];
    };
  };
  krb5.domain_realm = {
    "exchange.mit.edu" = "EXCHANGE.MIT.EDU";
    "mit.edu" = "ATHENA.MIT.EDU";
    "win.mit.edu" = "WIN.MIT.EDU";
    "csail.mit.edu" = "CSAIL.MIT.EDU";
    "media.mit.edu" = "MEDIA-LAB.MIT.EDU";
    "whoi.edu" = "ATHENA.MIT.EDU";
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
    ];
  };
}
