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
        cdparanoia
        cdrkit
        codec2
        flac
        ((if config.isz.graphical then ffmpeg-full else ffmpeg-headless).override {
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
      ] ++ available youtube-dl
        ++ available jellycli
        ++ lib.optionals pkgs.stdenv.isLinux [
        dvdbackup
        mikmod
        vapoursynth
        timidity
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        audacity
        (dav1d.override {
          withTools = true;
          withExamples = true;
        })
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        avidemux # https://github.com/iains/gcc-darwin-arm64/issues/3 https://github.com/orgs/Homebrew/discussions/3296
        guvcview
        delfin
        haruna
        jellyfin-media-player
        jftui
        kdePackages.kdenlive
        mkvtoolnix
        smplayer
        vlc
        vmpk
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
    })
    # Multimedia - PipeWire
    {
      home.packages = with pkgs; [
        pulsemixer
      ];
    }
    (lib.mkIf (pkgs.stdenv.isLinux && config.isz.graphical) {
      home.packages = with pkgs; [
        lxqt.pavucontrol-qt
        ncpamixer
        helvum
        qpwgraph
      ];
    })
    # Multimedia - OBS
    (lib.mkIf (pkgs.stdenv.isLinux && config.isz.graphical) {
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
          (pkgs.obs-studio-plugins.obs-rgb-levels or obs-rgb-levels-filter)
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
    # Multimedia - Carla
    (lib.mkIf (pkgs.stdenv.isLinux && config.isz.graphical && (builtins.tryEval pkgs.carla.outPath).success) {
      home.packages = [
        pkgs.carla
      ];
    })
    # Multimedia - Audio
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        scope-tui
      ];
    })
    (lib.mkIf (pkgs.stdenv.isLinux && config.isz.graphical) (let
      pluginPath = type: "${config.home.profileDirectory}/lib/${type}";
      sfDir = "${config.home.profileDirectory}/share/soundfonts";
      commas = list: lib.concatStringsSep ", " list;
      colons = list: lib.concatStringsSep ":" list;
      paths = {
        clap = [
          "${config.home.homeDirectory}/.clap"
          (pluginPath "clap")
        ];
        dssi = [
          "${config.home.homeDirectory}/.dssi"
          (pluginPath "dssi")
        ];
        ladspa = [
          "${config.home.homeDirectory}/.ladspa"
          (pluginPath "ladspa")
        ];
        lv2 = [
          "${config.home.homeDirectory}/.lv2"
          (pluginPath "lv2")
        ];
        sf2 = [
          "${config.home.homeDirectory}/.sounds/sf2"
          "${config.home.homeDirectory}/.sounds/sf3"
          sfDir
          "${config.home.profileDirectory}/share/sounds/sf2"
          "${config.home.profileDirectory}/share/sounds/sf3"
        ];
        sfz = [
          "${config.home.homeDirectory}/.sounds/sfz"
          "${config.home.profileDirectory}/share/sounds/sfz"
        ];
        vst2 = [
          "${config.home.homeDirectory}/.vst"
          "${config.home.homeDirectory}/.wine/drive_c/Program Files (x86)/VstPlugins"
          "${config.home.homeDirectory}/.wine/drive_c/Program Files/VstPlugins"
          (pluginPath "lxvst")
          (pluginPath "vst")
        ];
        vst3 = [
          "${config.home.homeDirectory}/.vst3"
          "${config.home.homeDirectory}/.wine/drive_c/Program Files (x86)/Common Files/VST3"
          "${config.home.homeDirectory}/.wine/drive_c/Program Files/Common Files/VST3"
          (pluginPath "vst3")
        ];
      };
    in {
      home.packages = with pkgs; [
        # N.B. Can't use unstable packages or they won't be able to load plugins.

        # apps.linuxaudio.org

        # DAWs/plugin hosts
        ardour
        qtractor
        plugin-torture
        ams

        # Utilities
        jaaa
        japa
        losslesscut-bin
        rsgain

        # Plugins
        qsynth
        fluidsynth
        synthv1
        dssi
        ladspa-sdk
        ladspaPlugins
        lsp-plugins
        lv2
        soundfont-fluid
        #missing signalizer
        #https://github.com/JoepVanlier/JSFX
        #https://github.com/geraintluff/jsfx
        #https://github.com/Justin-Johnson/ReJJ
      ] ++ (lib.optional juce.meta.available ysfx);
      home.sessionVariables = {
        CLAP_PATH = colons paths.clap;
        DSSI_PATH = colons paths.dssi;
        LADSPA_PATH = colons paths.ladspa;
        LV2_PATH = colons paths.lv2;
        LXVST_PATH = colons paths.vst2;
      };
      programs.plasma.configFile."rncbc.org/Qtractor.conf" = {
        Default.InstrumentDir = "${pkgs.qtractor}/share/qtractor/instruments"; # Broken default value
        InstrumentFiles.File1 = "${pkgs.qtractor}/share/qtractor/instruments/Standard1.ins";
        Plugins.ClapPaths = commas paths.clap;
        Plugins.DssiPaths = commas paths.dssi;
        Plugins.LadspaPaths = commas paths.ladspa;
        Plugins.Lv2Paths = commas paths.lv2;
        #Plugins.Lv2PresetDir=
        Plugins.Vst2Paths = commas paths.vst2;
        Plugins.Vst3Paths = commas paths.vst3;
      };
      programs.plasma.configFile."rncbc.org/Qsynth.conf" = {
        Defaults.SoundFontDir = sfDir;
        SoundFonts.SoundFont1 = "${sfDir}/FluidR3_GM2-2.sf2";
      };
      programs.plasma.configFile."falkTX/Carla2.conf" = {
        Paths = {
          DSSI = commas paths.dssi;
          LADSPA = commas paths.ladspa;
          LV2 = commas paths.lv2;
          SF2 = commas paths.sf2;
          SFZ = commas paths.sfz;
          VST2 = commas paths.vst2;
          VST3 = commas paths.vst3;
        };
      };
    }))
  ]);
}
