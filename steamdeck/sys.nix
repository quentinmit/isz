{ nixpkgs, self, specialArgs, ... }:

let
  system = "x86_64-linux";
  sysext = import ../nix/sysext.nix {
    inherit system self nixpkgs specialArgs;
    modules = [
      ./configuration.nix
    ];
  };
  inherit (sysext) pkgs;
  generateSystemd = name: config:
    pkgs.writeText "${name}" sysext.config.systemd.units."${name}".text;
  manifest = {
    symlink = {
      "/etc/systemd/system/telegraf.service" = {
        path = generateSystemd "telegraf.service" sysext;
      };
    };
  };
  # nix-sys = (import nix-sys-repo {
  #   inherit pkgs;
  # });
in {
  inherit sysext;
  activate = pkgs.writeShellScript "activate.sh" ''
    ln -sf /etc/systemd/system/telgraf.service ${generateSystemd "telegraf.service" sysext}
  '';
}
#nix-sys.nix-sys.override {
#  manifest = pkgs.writeText "manifest.json" (builtins.toJSON manifest);
#  nixsys-preprocess = pkgs.callPackage "${nix-sys-repo}/preprocess/package.nix" {
#    version = "8107";
#  };
#}
