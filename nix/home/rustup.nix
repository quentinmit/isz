{ config, pkgs, lib, ... }:
let
  cfg = config.programs.rustup;
  cfgCargo = config.programs.cargo;
  tomlFormat = pkgs.formats.toml {};
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
          pkgs.stdenv.hostPlatform.rust.rustcTarget
        ];
      };
    };
    programs.cargo = {
      settings = mkOption {
        inherit (tomlFormat) type;
        default = {};
      };
    };
  };
  config = let
    nixpkgs = pkgs.symlinkJoin rec {
      name = "rust-${version}";
      inherit (pkgs.rustc) version;
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
    programs.cargo.settings.target = lib.mkIf (!pkgs.stdenv.isLinux) {
      "x86_64-unknown-linux-gnu".linker = "${pkgs.pkgsCross.gnu64.stdenv.cc}/bin/x86_64-unknown-linux-gnu-cc";
    };
    home.file.".rustup/toolchains/nixpkgs-${nixpkgs.version}".source = nixpkgs;
    home.file.".rustup/toolchains/nixpkgs".source = nixpkgs;
    home.file.".rustup/toolchains/nix-stable-${stable.version}".source = stable;
    home.file.".rustup/toolchains/nix-stable".source = stable;
    home.file.".cargo/config.toml".source = tomlFormat.generate "cargo.toml" cfgCargo.settings;

    services.baloo.excludeFolders = [
      "$HOME/.rustup/"
      "$HOME/.cargo/git/"
      "$HOME/.cargo/registry/"
    ];
  };
}
