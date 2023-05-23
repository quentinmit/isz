{ config, pkgs, lib, ... }:
{
  options = with lib; {
    programs.macfuse.enable = mkEnableOption "macFUSE kernel module";
  };
  config = lib.mkIf (config.programs.macfuse.enable) {
    environment.pathsToLink = [ "/Library/Filesystems" ];
    environment.systemPackages = [ pkgs.macfuse ];
    system.activationScripts.extraActivation.text = ''
      ln -sf @out@/sw/Library/Filesystems/macfuse.fs /Library/Filesystems/macfuse.fs
      # N.B. This will put a setuid file in the Nix store!
      chmod u+s /Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse
    '';
  };
}
