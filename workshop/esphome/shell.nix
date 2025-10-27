{ mkShell
, esphome
, ltchiptool
, python3
}:

mkShell {
  packages = [
    esphome
    ltchiptool
    python3.pkgs.bk7231tools
  ];
}
