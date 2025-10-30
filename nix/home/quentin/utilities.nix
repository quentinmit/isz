{ config, lib, pkgs, ... }:
{
  options.isz.quentin.utilities.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.utilities.enable {
    home.packages = with pkgs; [
      ack
      brotli
      bsdiff
      btop
      cabextract
      csview
      csvlens
      colordiff
      dasel
      debianutils
      (fortune.override {
        withOffensive = true;
      })
      fd
      file-rename
      fq
      gcab
      gnutar
      units
      htmlq
      jc
      jless
      (pkgs.runCommand "jmespath-jp" {} ''
        mkdir -p $out/bin
        cp ${jp}/bin/jp $out/bin/jmespath
      '')
      json-plot
      less
      libxml2
      libxslt
      libzip
      lnav
      lzip
      xz
      miller
      moreutils
      most
      ncdu
      p7zip
      perlPackages.JSONXS
      perlPackages.StringShellQuote
      pigz
      pixz
      pv
      renameutils
      ripgrep
      rlwrap
      sharutils
      sl
      tmate
      libuchardet
      unrar
      vbindiff
      vttest
      xdelta
      xmlstarlet
      xqilla
      (pkgs.xan or pkgs.xsv)
      (yazi.override (old: {
        ffmpeg = if config.isz.graphical then old.ffmpeg else ffmpeg-headless;
      }))
      yj
      yq
    ] ++ lib.optionals (config.isz.graphical && pkgs.stdenv.isLinux) ([
      d-spy
      devtoolbox
      wl-clipboard
    ] ++ lib.optional (config.isz.graphical && !bustle.meta.broken) bustle);
  };
}
