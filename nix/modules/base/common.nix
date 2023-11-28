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

    nix.package = lib.mkDefault pkgs.nixVersions.nix_2_16;

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      # Nix on macOS has a race condition when this is turned on.
      # https://github.com/NixOS/nix/issues/7273
      auto-optimise-store = lib.mkIf (!pkgs.stdenv.isDarwin) true;
      # sops-nix uses garnix.io
      substituters = [
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = options._module.specialArgs.value;
    home-manager.sharedModules = builtins.attrValues self.homeModules;

    environment.systemPackages = import ./packages.nix { inherit pkgs; } ++ [
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
