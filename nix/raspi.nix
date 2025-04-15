{ config, pkgs, lib, modulesPath, nixos-hardware, ... }:

let
  toConfigTxt = with builtins; let
    recurse = path: value:
      if isAttrs value then
        lib.mapAttrsToList (name: recurse ([ name ] ++ path)) value
      else
        {
          conditionals = lib.lists.sort builtins.lessThan (filter (k: k != "all") (tail path));
          name = head path;
          inherit value;
        };
    groupItems = items:
      (lib.attrsets.mapAttrsToList
        (groupJSON: items:
          {
            conditionals = fromJSON groupJSON;
            inherit items;
          })
        (lib.attrsets.mapAttrs
          (k: builtins.listToAttrs)
          (builtins.groupBy
            (x: toJSON x.conditionals)
            items
          )
        )
      );
    mkValueString = v:
      if isInt v then toString v
      else if isString v then v
      else if true == v then "1"
      else if false == v then "0"
      else abort "the value is not supported: ${toPretty {} (toString v)}";
    mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } "=";
    mkGroup = group:
      lib.strings.concatMapStrings (k: "[${k}]\n") group.conditionals
        + lib.generators.toKeyValue { inherit mkKeyValue; listsAsDuplicateKeys = true; } group.items
    ;
    in
      attrs:
      let
        groups = lib.lists.sort
          (a: b: a.conditionals < b.conditionals)
          (groupItems (lib.flatten (recurse [] attrs)));
      in
        lib.strings.concatMapStringsSep "\n[all]\n" mkGroup groups;
in
{
  disabledModules = [
    "system/boot/loader/generic-extlinux-compatible"
  ];
  imports = [
    nixos-hardware.nixosModules.raspberry-pi-4
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  options = with lib; {
    boot.loader.generic-extlinux-compatible = {
      enable = mkEnableOption "bogus";
    };
    boot.loader.isz-raspi = {
      uboot = mkOption {
        type = with types; attrsOf package;
        default = {
          rpi3 = pkgs.ubootRaspberryPi3_64bit;
          rpi4 = pkgs.ubootRaspberryPi4_64bit;
        };
      };
      forceHDMI = mkEnableOption "Force HDMI output";
      configurationLimit = mkOption {
        default = 20;
        example = 10;
        type = types.int;
        description = lib.mdDoc ''
          Maximum number of configurations in the boot menu.
        '';
      };
      config = mkOption {
        type = with types; let
          atom = oneOf [str int bool];
          molecule = oneOf [atom (listOf atom) (attrsOf molecule)];
        in attrsOf molecule;
        default = {};
        description = "config.txt options";
      };
    };
    rpi.serialConsole = mkOption {
      type = types.bool;
      default = true;
      description = "Enable serial console on ttyAMA0";
    };
  };

  config = let
    blCfg = config.boot.loader;
    dtCfg = config.hardware.deviceTree;
    cfg = blCfg.isz-raspi;
    isRpi3 = cfg.uboot ? rpi3;
    isRpi4 = cfg.uboot ? rpi4;

    timeoutStr = if blCfg.timeout == null then "-1" else toString blCfg.timeout;

    ecbn = "${modulesPath}/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix";
    # The builder used to write during system activation
    ecbBuilder = pkgs.callPackage ecbn {};
    # The builder which runs on the build architecture
    ecbPopulateBuilder = pkgs.buildPackages.callPackage ecbn {};
    ecbBuilderArgs = "-g ${toString cfg.configurationLimit} -t ${timeoutStr}"
      + lib.optionalString (dtCfg.name != null) " -n ${dtCfg.name}";

    configTxtPkg = pkgs.writeText "config.txt" (toConfigTxt cfg.config);
    cp = lib.getExe' pkgs.coreutils "cp";
    copyRpiFirmware = lib.strings.concatMapStringsSep "\n" (f: "${cp} ${pkgs.raspberrypifw}/share/raspberrypi/boot/${f} firmware/") [
      "bootcode.bin"
      "fixup4cd.dat"
      "fixup4.dat"
      "fixup4db.dat"
      "fixup4x.dat"
      "fixup.dat"
      "fixup_cd.dat"
      "fixup_db.dat"
      "fixup_x.dat"
      "start4cd.elf"
      "start4db.elf"
      "start4.elf"
      "start4x.elf"
      "start.elf"
      "start_cd.elf"
      "start_db.elf"
      "start_x.elf"
      "bcm2711-rpi-4-b.dtb"
      "bcm2711-rpi-400.dtb"
      "bcm2711-rpi-cm4.dtb"
      "bcm2711-rpi-cm4s.dtb"
    ];
    populateFirmwareCommands = ''
      if [ -n "''${img:+present}" ] || ${pkgs.util-linux}/bin/findmnt /boot/firmware > /dev/null; then
        # Add the config
        ${cp} ${configTxtPkg} firmware/config.txt
        ${lib.optionalString isRpi3 ''
        # Add pi3 specific files
        ${cp} ${cfg.uboot.rpi3}/u-boot.bin firmware/u-boot-rpi3.bin
        ''}
        ${lib.optionalString isRpi4 ''
        # Add pi4 specific files
        ${cp} ${cfg.uboot.rpi4}/u-boot.bin firmware/u-boot-rpi4.bin
        ''}
        ${cp} ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin firmware/armstub8-gic.bin
        ${copyRpiFirmware}
        echo "rpi firmware installed"
      else
        echo "/boot/firmware not mounted; skipping firmware installation"
      fi
    '';
  in
  {
    nixpkgs.hostPlatform = { system = "aarch64-linux"; };
    #nixpkgs.buildPlatform = { system = "x86_64-linux"; config = "x86_64-unknown-linux-gnu"; };
    nixpkgs.overlays = [
      # Allow RPi kernel to be used despite missing modules.
      (final: super: {
        makeModulesClosure = x:
          super.makeModulesClosure (x // { allowMissing = true; });
      })
      (final: super: {
        ubootRaspberryPi4_64bit_nousb = super.ubootRaspberryPi4_64bit.override {
          # Work around hang by not initializing USB:
          # https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=256441
          extraConfig = ''
            CONFIG_PREBOOT="pci enum;"
          '';
        };
      })
    ];

    boot.loader.isz-raspi.config = lib.mkMerge [
      {
        pi4.kernel = lib.mkIf isRpi4 (lib.mkDefault "u-boot-rpi4.bin");
        pi4.enable_gic = lib.mkDefault true;
        pi4.armstub = lib.mkDefault "armstrub8-gic.bin";
        pi3.kernel = lib.mkIf isRpi3 (lib.mkDefault "u-boot-rpi3.bin");
        pi02.kernel = lib.mkIf isRpi3 (lib.mkDefault "u-boot-rpi3.bin");

        # U-Boot used to need this to work, regardless of whether UART is actually used or not.
        # TODO: check when/if this can be removed.
        enable_uart = lib.mkDefault true;

        # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
        # when attempting to show low-voltage or overtemperature warnings.
        avoid_warnings = lib.mkDefault true;

        # Boot in 64-bit mode
        arm_64bit = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 true;
      }
      (lib.mkIf cfg.forceHDMI {
        # Force HDMI out
        hdmi_force_hotplug = true;
        # Force 1080p60
        hdmi_group = 1;
        hdmi_mode = 16;
      })
    ];

    boot = {
      # ttyAMA0 is the serial console broken out to the GPIO
      kernelParams = lib.mkMerge [
        [
          "cgroup_enable=memory"
        ]
        (lib.mkIf config.rpi.serialConsole [
          "8250.nr_uarts=1"
          "console=ttyAMA0,115200"
          "console=tty1"
        ])
      ];

      loader.grub.enable = false;
    };

    virtualisation.vmVariant = {
      boot.initrd.kernelModules = [
        "pci-host-generic"
      ];
      rpi.serialConsole = false;
      boot.kernelParams = [
        "console=ttyAMA0"
        "boot.shell_on_fail"
        "sysrq_always_enabled"
      ];
    };

    system.build.installBootLoader = pkgs.writeShellScript "isz-boot-builder" ''
      set -euo pipefail
      ${ecbBuilder} ${ecbBuilderArgs} -c "$@"
      (
        echo "installing the firmware..."
        cd /boot;
        ${populateFirmwareCommands}
      )
    '';
    system.boot.loader.id = "isz-raspi";

    sdImage = {
      inherit populateFirmwareCommands;
      populateRootCommands = ''
        mkdir -p ./files/boot
        ${ecbPopulateBuilder} ${ecbBuilderArgs} -c ${config.system.build.toplevel} -d ./files/boot
      '';
    };
  };
}

