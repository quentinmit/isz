{ config, lib, pkgs, ... }:
let
  cfg = config.programs.kdo;
  kdo = pkgs.fetchurl {
    url = "https://web.mit.edu/snippets/kerberos/kdo";
    hash = "sha256-Rl31a0nEvKMi+B1I84JmlBqmg3G4YqwNJqWbU8QKKtI=";
  };
in {
  options = with lib; {
    programs.kdo = {
      enable = mkEnableOption "kdo support";
      args = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Arguments to pass to kinit if new tickets are needed";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs.bash.initExtra = ''
      . ${kdo}
      ${lib.optionalString (cfg.args != null) ''kdo_args=(${cfg.args})''}
    '';
  };
}
