{ config, pkgs, lib, ... }:

{
  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "25.05";

      isz.base = true;

      isz.quentin.mail.enable = true;

      home.packages = with pkgs; [
        (writeShellScriptBin "greptimedb-mcp-server" ''
          export GREPTIMEDB_USER="''${GREPTIMEDB_USER:-quentin}"
          export GREPTIMEDB_PASSWORD="''${GREPTIMEDB_PASSWORD:-$(cat ${lib.escapeShellArg config.sops.secrets."greptimedb/users/quentin".path})}"
          exec ${lib.getExe unstable.greptimedb-mcp-server} "$@"
        '')
      ];
    }
  ];
}
