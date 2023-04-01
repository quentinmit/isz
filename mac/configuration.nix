{ config, pkgs, lib, ... }:

{
  environment.systemPackages = [
  ];

  programs.bash = {
    enable = true;
    enableCompletion = true;
    interactiveShellInit = ''
      PS1='\h:\W \u\$ '
    '';
  };

  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    bash-prompt-prefix = "(nix:$name)\\040";
  };
}
