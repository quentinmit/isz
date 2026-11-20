{ config, lib, pkgs, ...}:
let
  # From nixos/modules/config/nix-remote-build.nix
  mkBuildMachinesText = let
    inherit (lib) concatMapStrings concatStringsSep optional optionalString;
    isNixAtLeast = lib.versionAtLeast (lib.getVersion config.nix.package);
  in concatMapStrings (
    machine:
    (concatStringsSep " " (
      [
        "${optionalString (machine.protocol != null) "${machine.protocol}://"}${
          optionalString (machine.sshUser != null) "${machine.sshUser}@"
        }${machine.hostName}"
        (
          if machine.system != null then
            machine.system
          else if machine.systems != [ ] then
            concatStringsSep "," machine.systems
          else
            "-"
        )
        (if machine.sshKey != null then machine.sshKey else "-")
        (toString machine.maxJobs)
        (toString machine.speedFactor)
        (
          let
            res = (machine.supportedFeatures ++ machine.mandatoryFeatures);
          in
          if (res == [ ]) then "-" else (concatStringsSep "," res)
        )
        (
          let
            res = machine.mandatoryFeatures;
          in
          if (res == [ ]) then "-" else (concatStringsSep "," machine.mandatoryFeatures)
        )
      ]
      ++ optional (isNixAtLeast "2.4pre") (
        if machine.publicHostKey != null then machine.publicHostKey else "-"
      )
    ))
    + "\n"
  );
in {
  sops.secrets."nix/builders/build-arm/id_ed25519" = {};
  services.hydra = {
    enable = true;
    hydraURL = "https://hydra.isz.wtf";
    listenHost = "localhost";
    notificationSender = "hydra@isz.wtf";
    minimumDiskFree = 250;
    useSubstitutes = true;
    buildMachinesFiles = [
      (pkgs.writeText "hydra-build-machines" (mkBuildMachinesText [
        {
          hostName = "build-arm.isz.wtf";
          sshUser = "hydra-workshop";
          sshKey = config.sops.secrets."nix/builders/build-arm/id_ed25519".path;
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUxlZ1prVTBwNGtQTzdXNFZUdE1RaWRJTERoNzJPRFBFTXZoQWJDUnJHKzEgcm9vdEBidWlsZC1hcm0K";
          protocol = "ssh-ng";
          systems = [
            "aarch64-linux"
            "armv7l-linux"
            "armv8l-linux"
          ];
          maxJobs = 4;
          supportedFeatures = [
            "big-parallel"
          ];
        }
      ]))
    ];
    extraConfig = ''
      <hydra_notify>
        <prometheus>
          listen_address = 127.0.0.1
          port = 9199
        </prometheus>
      </hydra_notify>
    '';
  };
  isz.telegraf.prometheus.apps = {
    hydra-notify.url = "http://localhost:9199/metrics";
    hydra-queue-runner.port = "http://localhost:9198/metrics";
  };
  nix.trustedUsers = ["hydra" "hydra-evaluator" "hydra-queue-runner"];
  services.nginx = {
    upstreams.hydra.servers."localhost:${toString config.services.hydra.port}" = {};
    virtualHosts."hydra.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://hydra";
    };
  };
}
