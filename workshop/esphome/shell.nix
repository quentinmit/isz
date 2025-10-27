{ mkShell
, esphome
, ltchiptool
}:

mkShell {
  packages = [
    esphome
    ltchiptool
  ];
}
