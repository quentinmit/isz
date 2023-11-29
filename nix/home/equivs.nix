{ config, pkgs, lib, ... }:
let
  mkEquivs = packages: pkgs.runCommand "equivs-dpkg" {
    nativeBuildInputs = [ pkgs.equivs ];
    equivsFile = ''
      Section: misc
      Priority: optional
      Standards-Version: 3.9.2
      Package: home-manager-debs-${config.home.username}
      Depends: ${lib.concatStringsSep "," config.deb.packages}
      Description: Home Manager-controlled debs for ${config.home.username}
    '';
  } ''
    env
    equivs-build $equivsFile
    mkdir $out
    mv *.deb $out/
  '';
  pkg = mkEquivs config.deb.packages;
in {
  options = with lib; {
    deb.packages = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''List of Debian packages to build into an equivs package (install with the "home-install-debs" command)'';
    };
  };
  config = {
    home.packages = lib.mkIf (config.deb.packages != []) [(
      pkgs.writeShellScriptBin "home-manager-install-debs" ''
        exec sudo apt install ${pkg}/*.deb
      ''
    )];
  };
}
