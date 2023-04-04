{ config, pkgs, lib, home-manager, ... }:

{
  imports = [
    home-manager.darwinModules.home-manager
    ../nix/modules/base
    ../nix/modules/telegraf
  ];

  environment.systemPackages = with pkgs; [
    statix
    telegraf
    (ffmpeg-full.override {
      nonfreeLicensing = true;
    })
  ];

  programs.bash = {
    enable = true;
    enableCompletion = true;
    interactiveShellInit = ''
      PS1='\h:\W \u\$ '
    '';
  };

  isz.telegraf.enable = true;
  services.telegraf.environmentFiles = [
    ./telegraf.env
  ];

  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    bash-prompt-prefix = "(nix:$name)\\040";
  };
  system.stateVersion = 4;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.quentin = {
    home.stateVersion = "22.11";
    programs.home-manager.enable = true;

    programs.git = {
      enable = true;
      ignores = [
        "*~"
        "*#"
        ".ipynb_checkpoints"
        "__pycache__"
      ];
      userName = "Quentin Smith";
      userEmail = "quentin@mit.edu";
      aliases = {
        up = "pull --rebase";
        k = "log --graph --abbrev-commit --pretty=oneline --decorate";
      };
      extraConfig = {
        url = {
          "git@github.com:".pushInsteadOf = "https://github.com/";
          "git@github.mit.edu:".insteadOf = "https://github.mit.edu/";
          "git@gitlab.com:".pushInsteadOf = "https://gitlab.com/";
        };
      };
    };
  };
}
