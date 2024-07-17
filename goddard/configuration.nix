{ config, pkgs, lib, nixpkgs, disko, nixos-hardware, lanzaboote, ... }:
{
  imports = [
    #./hardware-configuration.nix
    nixos-hardware.nixosModules.framework-16-7040-amd
    ./disko.nix
    disko.nixosModules.disko
    ./quentin.nix
    ./opensnitch.nix
    lanzaboote.nixosModules.lanzaboote
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
  boot.kernelParams = [''dyndbg="file drivers/base/firmware_loader/main.c +fmp"''];

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

  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "95";
    }
    {
      domain = "@audio";
      item = "nice";
      type = "-";
      value = "-19";
    }
  ];

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
    kdePackages.plasma-firewall
    kdePackages.plasma-thunderbolt
    thunderbolt
    glxinfo
    libva-utils
    clinfo
    nvtopPackages.amd
    radeontop
    kio-fuse
    pipewire.jack
    wd-fw-update
    mosh-server-upnp
    vde2
    openrgb-with-all-plugins
  ];

  services.udev.packages = with pkgs; [
    platformio-core.udev
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

  fonts.fontDir.enable = true;
  fonts.fontconfig.subpixel.rgba = "rgb";

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

  programs.dconf.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
  };

  # TODO: Switch to systemd-resolved for mDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  security.pam.krb5.enable = false;
  security.krb5 = {
    enable = true;
    settings.libdefaults.default_realm = "ATHENA.MIT.EDU";
    settings.realms = {
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
    settings.domain_realm = {
      "exchange.mit.edu" = "EXCHANGE.MIT.EDU";
      "mit.edu" = "ATHENA.MIT.EDU";
      "win.mit.edu" = "WIN.MIT.EDU";
      "csail.mit.edu" = "CSAIL.MIT.EDU";
      "media.mit.edu" = "MEDIA-LAB.MIT.EDU";
      "whoi.edu" = "ATHENA.MIT.EDU";
    };
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
  };
}
