{ config, pkgs, lib, ... }:
{
  options = with lib; {
    programs.macfuse.enable = mkEnableOption "macFUSE kernel module";
  };
  config = lib.mkIf (config.programs.macfuse.enable) {
    environment.pathsToLink = [ "/Library/Filesystems" ];
    environment.systemPackages = [ pkgs.macfuse ];
    system.activationScripts.extraActivation.text = ''
      # N.B. Can't use a symlink because load_macfuse needs to be setuid.
      rsync -a --delete --inplace --exclude macfuse.fs/Contents/Resources/load_macfuse @out@/sw/Library/Filesystems/macfuse.fs/ /Library/Filesystems/macfuse.fs
      rsync -a --inplace --chmod=u+s @out@/sw/Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse /Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse
    '';
  };
}
