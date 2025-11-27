{ lib, pkgs, config, ... }:
{
  programs.ssh.package = pkgs.openssh_gssapi;
  nixpkgs.overlays = [(final: prev: {
    pssh = prev.pssh.override {
      openssh = config.programs.ssh.package;
    };
  })];
  home-manager.users.quentin = {
    programs.ssh.package = pkgs.openssh_gssapi;
    programs.git.settings = {
      core.sshCommand = lib.getExe pkgs.openssh_gssapi;
    };
    # Mosh takes `--ssh=${lib.getExe pkgs.openssh_gssapi}` as an arg
    # libvirt takes `?command=${lib.getExe pkgs.openssh_gssapi}` as part of the connection URI
    # sshfs takes `-o ssh_command=${lib.getExe pkgs.openssh_gssapi}` as an arg
  };
}
