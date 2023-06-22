{ config, pkgs, lib, ... }:
let
  cfg = config.programs.rustup;
in {
  options = with lib; {
    programs.rustup = {
      enable = mkEnableOption "rustup";
      extensions = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      targets = mkOption {
        type = types.listOf types.str;
        default = [
          pkgs.hostPlatform.config
        ];
      };
    };
  };
  config = let
    nixpkgs = pkgs.symlinkJoin rec {
      name = "rust-${version}";
      version = pkgs.rustc.version;
      paths = with pkgs; [
        rustc
        cargo
        rustfmt
      ];
    };
    stable = pkgs.rust-bin.stable.latest.default.override {
      inherit (cfg) extensions targets;
    };
  in lib.mkIf cfg.enable {
    home.packages = [
      pkgs.rustup
    ];
    home.file.".rustup/toolchains/nixpkgs-${nixpkgs.version}".source = nixpkgs;
    home.file.".rustup/toolchains/nixpkgs".source = nixpkgs;
    home.file.".rustup/toolchains/nix-stable-${stable.version}".source = stable;
    home.file.".rustup/toolchains/nix-stable".source = stable;
  };
}
