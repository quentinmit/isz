{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    esphome
  ];
}
