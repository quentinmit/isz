{ config, lib, pkgs, ... }:
let
  available = pkg: lib.optional pkg.meta.available pkg;
in {
  options = {
    isz.quentin.multimedia = lib.mkOption {
      type = lib.types.bool;
      default = config.isz.quentin.enable;
    };
  };
  config = lib.mkIf config.isz.quentin.multimedia (lib.mkMerge [
    # Multimedia
    {
      home.packages = with pkgs; [
        atomicparsley
        audacity
        cdparanoia
        cdrkit
        codec2
        (dav1d.override {
          withTools = true;
          withExamples = true;
        })
        flac
        (ffmpeg-full.override {
          withUnfree = true;
        })
        gsm
        id3lib
        #id3tool
        libde265
        mediainfo
        rav1e
        rtmpdump
        sox
        tsduck
        yt-dlp
        jellycli
      ] ++ available youtube-dl
        ++ lib.optionals pkgs.stdenv.isLinux [
        avidemux # https://github.com/iains/gcc-darwin-arm64/issues/3 https://github.com/orgs/Homebrew/discussions/3296
        ardour
        dvdbackup
        guvcview
        mikmod
        mkvtoolnix
        vapoursynth
        vlc
        kdePackages.kdenlive
        timidity
        vmpk
        jellyfin-media-player
        jftui
        delfin
      ];
      programs.mpv = {
        enable = true;
        bindings = {
          PGDWN = "seek -600";
          PGUP = "seek 600";
          "Shift+PGDWN" = "add chapter -1";
          "Shift+PGUP" = "add chapter 1";

          KP1 = "add video-rotate -90";
          KP2 = "add video-pan-y -0.01";
          KP3 = "add video-rotate +90";
          KP4 = "add video-pan-x +0.01";
          KP5 = "set video-pan-x 0; set video-pan-y 0; set video-zoom 0";
          KP6 = "add video-pan-x -0.01";
          KP7 = "add video-zoom -0.01";
          KP8 = "add video-pan-y +0.01";
          KP9 = "add video-zoom +0.01";
          b = "osd-msg script-message curves-brighten-show";
          y = "osd-msg script-message curves-cooler-show";
          c = "script_message show-clock";
        };
      };
      xdg.configFile."youtube-dl/config".text = ''
        --netrc
      '';
      xdg.configFile."yt-dlp/config".text = ''
        --ap-mso Spectrum
        --netrc
      '';
    }
    # Multimedia - PipeWire
    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        lxqt.pavucontrol-qt
        ncpamixer
        helvum
        qpwgraph
      ];
    })
    # Multimedia - OBS
    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = [(pkgs.wrapOBS {
        plugins = with pkgs.obs-studio-plugins; [
          droidcam-obs
          input-overlay
          obs-3d-effect
          obs-backgroundremoval
          obs-freeze-filter
          obs-gradient-source
          obs-gstreamer
          obs-move-transition
          #obs-multi-rtmp
          #obs-ndi
          obs-pipewire-audio-capture
          obs-replay-source
          obs-rgb-levels-filter
          obs-scale-to-sound
          obs-shaderfilter
          obs-source-clone
          obs-source-record
          obs-teleport
          obs-text-pthread
          obs-vaapi
          obs-vintage-filter
          obs-vkcapture
          waveform
        ];
      })];
    })
  ]);
}
