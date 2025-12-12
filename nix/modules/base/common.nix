{ lib, pkgs, config, nix-index-database, home-manager, options, sops-nix, self, ... }:
# This config file is loaded by both nixos and nix-darwin, so only options that
# exist on both can be placed here. See ./default.nix and ../darwin/base.nix for
# OS-specific options.
{
  options = with lib; {
  };
  config = {
    time.timeZone = "America/New_York";

    nixpkgs.config.allowUnfree = true;

    nix.package = lib.mkDefault pkgs.nixVersions.latest;

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" ];
      # Nix on macOS has a race condition when this is turned on.
      # https://github.com/NixOS/nix/issues/7273
      auto-optimise-store = lib.mkIf (!pkgs.stdenv.isDarwin) true;
      # Preserve source for gcroots to make rebuilding faster.
      keep-outputs = true;
      # sops-nix uses garnix.io
      substituters = [
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "build-arm.isz.wtf-0:GNjLPEmW9L2kiFNDGmNPqqtxSh+v/HYHlyLqkrvf+Vk="
        "goddard.isz.wtf-0:DrWdaSAZghCxQ1eKxrVOu6iRrM2S8fs12baKmL9Hkps="
      ];
    };

    nix.registry.isz.flake = self;

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = {
      inherit (options._module.specialArgs.value)
        chemacs2nix
        deploy-rs
        dsd-fme
        plasma-manager;
    };
    home-manager.sharedModules = [({ lib, ... }: {
      # Don't let home-manager set LOCALE_ARCHIVE_2_27, so apps will fall back to LOCALE_ARCHIVE from the OS.
      disabledModules = [ "config/i18n.nix" ];
      # The option needs to exist because it is always set. :(
      options.i18n.glibcLocales = lib.mkOption {
        type = lib.types.package;
        default = config.i18n.glibcLocales;
        readOnly = true;
      };
    })] ++ builtins.attrValues self.homeModules;

    environment.systemPackages = with pkgs; import ./packages.nix { inherit pkgs; graphical = config.hardware.graphics.enable or true; } ++ [
      # Editors
      (pkgs.vim.customize {
        name = "vim";
        vimrcConfig.packages.default = {
          start = [ pkgs.vimPlugins.vim-nix ];
        };
        vimrcConfig.customRC = "syntax on";
      })
      (if pkgs.stdenv.buildPlatform.config != pkgs.stdenv.hostPlatform.config then
          emacs-nox
        else
          ((emacsPackagesFor emacs-nox).emacsWithPackages (epkgs: [
            epkgs.nix-mode
            epkgs.magit
            epkgs.go-mode
            epkgs.yaml-mode
          ]))
      )
    ];

    programs.wireshark.enable = true;

    environment.etc."snmp/snmp.conf".text = ''
      mibdirs +${pkgs.snmp-mibs}/share/snmp/mibs
      mibdirs +${pkgs.cisco-mibs}/v2
    '';
  };
}
