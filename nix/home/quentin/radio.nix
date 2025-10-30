{ config, lib, pkgs, ... }:
{
  options.isz.quentin.radio.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.radio.enable {
    home.packages = with pkgs; [
      dsd
      dsdcc
      #already gpsbabel
      #grig
      hamlib_4
      #already from soapysdr-with-plugins limesuite
      multimon-ng
      rtl-sdr
      rtl_433
      (rx_tools.override {
        soapysdr = soapysdr-with-plugins;
      })
      soapyhackrf
      sdrpp
    ] ++ lib.optionals config.isz.graphical (
      [
        gnuradio
        gpsbabel-gui
        nanovna-saver
        xastir
      ] ++ lib.optionals pkgs.stdenv.isLinux [
      csdr
      fldigi
      flrig
      pothos
      sdrangel
      ] ++ lib.optionals (!(pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)) [
        gqrx-portaudio
      ]
    ) ++ lib.optionals pkgs.stdenv.isLinux [
      gpsd
    ];
  };
}
