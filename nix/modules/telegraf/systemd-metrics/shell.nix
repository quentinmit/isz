{
  pkgs,
}:
pkgs.mkShell {
  packages = [
    pkgs.rust-analyzer
  ];
  inputsFrom = [
    pkgs.systemd-metrics
  ];
}
