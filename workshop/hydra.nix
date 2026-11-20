{ config, lib, pkgs, channels, ...}:
{
  # Remove unstable overrides when nixpkgs is 26.11
  disabledModules = [
    "services/continuous-integration/hydra/default.nix"
  ];
  imports = [
    "${channels.unstable}/nixos/modules/services/continuous-integration/hydra/default.nix"
    "${channels.unstable}/nixos/modules/services/continuous-integration/hydra/builder.nix"
  ];
  services.hydra.package = assert (!lib.versionAtLeast pkgs.hydra.version "0-unstable-2026-11-03"); pkgs.unstable.hydra;
  services.hydra.evaluatorPackage = pkgs.unstable.hydra-evaluator;
  services.hydra.queueRunner.package = pkgs.unstable.hydra-queue-runner;
  services.hydra.ws.package = pkgs.unstable.hydra-ws;
  services.hydra-builder.package = pkgs.unstable.hydra-builder;

  sops.secrets."hydra/tokens/workshop".owner = "hydra-queue-runner";
  sops.secrets."hydra/tokens/build-arm" = {
    owner = "hydra-queue-runner";
    sopsFile = ../build-arm/shared-secrets.yaml;
  };

  services.hydra = {
    enable = true;
    hydraURL = "https://hydra.isz.wtf";
    notificationSender = "hydra@isz.wtf";
    useSubstitutes = true;
    minimumDiskFree = 250; # GiB
    extraConfig = ''
      ws_endpoint = "wss://hydra.isz.wtf/ws"
      <hydra_notify>
        <prometheus>
          listen_address = 127.0.0.1
          port = 9199
        </prometheus>
      </hydra_notify>
    '';
    queueRunner.grpc.address = "[::]";
    ws.enable = true;
    ws.bind.unixSocket = "/run/hydra-ws.sock";
    queueRunner.settings.tokenPaths = lib.map (x: config.sops.secrets."hydra/tokens/${x}".path) [
      "workshop"
      "build-arm"
    ];
  };
  systemd.sockets.hydra-ws.socketConfig = {
    SocketUser = "nginx";
    SocketMode = "0600";
  };
  sops.secrets."hydra-builder/token" = {
    owner = "hydra-builder";
    key = "hydra/tokens/workshop";
  };
  services.hydra-builder = {
    enable = true;
    settings.buildDirAvailThreshold = 25.0; # percent
    authorizationFile = config.sops.secrets."hydra-builder/token".path;
    queueRunnerAddr = "http://hydra.isz.wtf:50051";
  };
  # TODO: Consider collecting statsd info from Hydra
  isz.telegraf.prometheus.apps = {
    hydra-notify.url = "http://localhost:9199/metrics";
    hydra-queue-runner.url = "http://localhost:9198/metrics";
  };
  nix.settings.trusted-users = ["hydra" "hydra-evaluator" "hydra-queue-runner"];
  services.nginx = {
    upstreams.hydra.servers."localhost:${toString config.services.hydra.port}" = {};
    upstreams.hydra-ws.servers."unix:${config.services.hydra.ws.bind.unixSocket}" = {};
    virtualHosts."hydra.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://hydra";
      locations."/ws".proxyPass = "http://hydra-ws";
    };
  };
}
