{ lib, pkgs, config, unstable, ... }:
{
  config = {
    nixpkgs.overlays = [
      (self: super: {
        inherit (pkgs.unstable) home-assistant;
      })
    ];
    disabledModules = [
      "services/home-automation/home-assistant.nix"
    ];
    imports = [
      "${channels.unstable}/nixos/modules/services/home-automation/home-assistant.nix"
    ];
    services.home-assistant = {
      enable = true;
      config.http = {
        trusted_proxies = [ "::1" "127.0.0.1" ];
        use_x_forwarded_for = true;
      };
    };
  };
}
