{ config, pkgs, disko, lib, ... }:
{
  imports = [
    ./disko.nix
    disko.nixosModules.disko
  ];

  nixpkgs.hostPlatform = { system = "aarch64-linux"; };

  sops.defaultSopsFile = ./secrets.yaml;

  hardware.deviceTree = {
    name = "rockchip/rk3588-orangepi-5-max.dtb";
    overlays = [{
      # The upstream device tree incorrectly puts rfkill on gpio0, which conflicts with the RTC interrupt pin.
      name = "99-rfkill";
      filter = "rockchip/rk3588-orangepi-5-max.dtb";
      # shutdown-gpios = <&gpio2 RK_PC5 GPIO_ACTIVE_HIGH>;
      dtsText = ''
        /dts-v1/;
        /plugin/;

        #include <dt-bindings/gpio/gpio.h>
        #include <dt-bindings/pinctrl/rockchip.h>

        /{
          compatible = "xunlong,orangepi-5-max";
          fragment@1 {
            target-path = "/rfkill";
            __overlay__ {
              status = "disabled";
            };
          };
        };
      '';
    }];
  };

  hardware.firmware = [
    pkgs.orangepi-firmware
  ];

  # TODO: Install pkgs.unstable.ubootOrangePi5Max

  # Use x86-64 qemu for run-vm
  virtualisation.vmVariantWithDisko = {
    virtualisation.qemu.package = pkgs.pkgsNativeGnu64.qemu;
    disko.devices.zpool.zpool = {
      rootFsOptions.keylocation = "file:///tmp/secret.key";
      preCreateHook = "echo 'secretsecret' > /tmp/secret.key";
      postCreateHook = "zfs set keylocation=prompt zpool";
    };
  };
  disko = {
    imageBuilder = {
      enableBinfmt = true;
      pkgs = pkgs.pkgsNativeGnu64;
      kernelPackages = pkgs.pkgsNativeGnu64.linuxPackages_6_15;
    };
  };

  boot = {
    # TODO: Add config from https://github.com/armbian/build/blob/ca4dc8085a50e65158fc788800b1423cd7334fb5/config/kernel/linux-rockchip-rk3588-edge.config
    # TODO: Do we need 6.16?
    kernelPackages = pkgs.linuxKernel.packages.linux_6_15;

    loader.grub.enable = false;
    loader.systemd-boot.enable = true;

    tmp.useTmpfs = true;
    initrd.systemd.enable = true;
    initrd.systemd.network = config.systemd.network;
    initrd.availableKernelModules = [
      # Display
      "rockchipdrm"
      "panthor"
      "display_connector"
      "phy_rockchip_naneng_combphy"
      "phy_rockchip_samsung_hdptx"
      "phy_rockchip_usbdp"
      # Ethernet
      "r8169"
      "bridge"
      "8021q"
      "cfg80211"
      "macvlan"
      "ip_tables"
      "nfnetlink"
      "tap"
      # RTC
      "rtc-hym8563"
    ];

    consoleLogLevel = 9;
    kernelParams = [
      "rootwait"

      "earlycon" # enable early console, so we can see the boot messages via serial port / HDMI
      "consoleblank=0" # disable console blanking(screen saver)
      "console=ttyS2,1500000" # serial port
      "console=tty1" # HDMI

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
    useTang = true;
    devices.zpool.secretFile = "/root/zpool.jwe";
  };

  networking.hostName = "build-arm";
  networking.hostId = "589a932a";

  isz.networking = {
    lastOctet = 39;
    macAddress = "C0:74:2B:FB:9A:4D";
  };

  isz.telegraf = {
    enable = true;
  };

  networking.firewall.enable = false;

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519"];
    useSops = true;
  };

  system.stateVersion = "25.05";

  users.users.root = {
    initialHashedPassword = "";
  };
}
