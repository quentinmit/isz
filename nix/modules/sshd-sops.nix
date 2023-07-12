{ lib, pkgs, config, ... }:
let
  cfg = config.isz.openssh;
in
{
  options = with lib; {
    isz.openssh = {
      hostKeyTypes = mkOption {
        default = [ "ecdsa" "ed25519" ];
        type = with types; listOf str;
        description = "Host key types to generate/load";
      };
      useSops = mkEnableOption "use sops";
    };
  };
  config = {
    services.openssh.hostKeys = map (t: { type = t; path = "/etc/ssh/ssh_host_${t}_key"; }) cfg.hostKeyTypes;
    sops.secrets = lib.mkIf cfg.useSops (
      lib.listToAttrs (
        map (t: {
          name = "ssh_host_keys/${t}";
          value = {
            # TODO: path will overwrite the key with a symlink that won't exist
            # on next activation.
            #path = "/etc/ssh/ssh_host_${t}_key";
          };
        }) cfg.hostKeyTypes
      )
    );

    system.activationScripts = lib.mkIf cfg.useSops {
      setupSecretsSsh = {
        deps = [ "setupSecrets" ];
        text = lib.strings.concatMapStringsSep "\n" (t: let
          src = config.sops.secrets."ssh_host_keys/${t}".path;
          dst = "/etc/ssh/ssh_host_${t}_key";
          in
	          with lib.strings;
            ''
              if [ -s ${escapeShellArg src} ]; then
                cp -a ${escapeShellArg src} ${escapeShellArg dst}
              fi
            '') cfg.hostKeyTypes;
      };
    };
  };
}

