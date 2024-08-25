{ config, pkgs, lib, ... }:

{
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "24.05";

      isz.base = true;
      isz.graphical = true;
      isz.quentin.multimedia = true;
    }
    # rtorrent
    {
      programs.rtorrent = {
        enable = true;
        extraConfig = ''
          upload_rate = 1000
          session = /home/quentin/hog-data/quentin/private/rtorrent-session
          port_random = yes
          dht = auto
          dht_port = 6882
          network.local_address.set = "127.0.0.1"
        '';
      };
    }
    # Emacs
    {
      programs.emacs = {
        enable = true;
        package = pkgs.emacs;
        extraPackages = epkgs: with epkgs; [
          nix-mode
          magit
          go-mode
          yaml-mode
        ];
      };
    }
  ];
}
