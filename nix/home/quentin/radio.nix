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
      gnuradio
      #already gpsbabel
      gpsbabel-gui
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
      xastir
      sdrpp
      nanovna-saver
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      csdr
      fldigi
      flrig
      gpsd
      pothos
      sdrangel
    ] ++ lib.optionals (!(pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)) [
      gqrx-portaudio
    ];
  };
}
