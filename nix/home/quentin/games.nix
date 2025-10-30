{ config, lib, pkgs, ... }:
{
  options.isz.quentin.games.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable && config.isz.graphical;
  };

  config = lib.mkIf config.isz.quentin.games.enable {
    home.packages = with pkgs; [
      igir
      lightsoff
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      bottles
      gnuchess # broken on macOS
      kdePackages.kblocks
      kdePackages.kbounce
      kdePackages.knights
      stockfish
      kdePackages.kmines
      kdePackages.knetwalk
      kdePackages.knavalbattle
      kdePackages.ksudoku
      kdePackages.kbreakout
      kdePackages.palapeli
      kdePackages.kolf
      aisleriot
      gnome-mines
      gnome-sudoku
      swell-foop
    ];
  };
}
