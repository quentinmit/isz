{ config, lib, pkgs, channels, ...}:
{
  # Remove unstable overrides when nixpkgs is 26.11
  imports = [
    "${channels.unstable}/nixos/modules/services/continuous-integration/hydra/builder.nix"
  ];
  services.hydra-builder.package = assert (!lib.versionAtLeast pkgs.hydra.version "0-unstable-2026-11-03"); pkgs.unstable.hydra-builder;

  sops.secrets."hydra-builder/token" = {
    owner = "hydra-builder";
    key = "hydra/tokens/build-arm";
    sopsFile = ./shared-secrets.yaml;
  };
  services.hydra-builder = {
    enable = true;
    settings.buildDirAvailThreshold = 25.0; # percent
    authorizationFile = config.sops.secrets."hydra-builder/token".path;
    queueRunnerAddr = "http://hydra.isz.wtf:50051";
  };
}
