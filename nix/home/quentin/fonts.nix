{ config, lib, pkgs, ... }:
{
  options.isz.quentin.fonts.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable && config.isz.graphical;
  };

  config = lib.mkIf config.isz.quentin.fonts.enable {
    home.packages = with pkgs; [
      # + default fonts in plasma.nix
      aileron
      fragment-mono
      helvetica-neue-lt-std
      bakoma_ttf
      vista-fonts
      gyre-fonts
      libertinus
      (google-fonts.override {
        fonts = [
          "Amiri"
          "Pathway Gothic One"
        ];
      })
      apple-fonts.SF-Pro
      apple-fonts.SF-Mono
      apple-fonts.SF-Compact
      apple-fonts.NY
      whatsapp-emoji-font
      source-code-pro
      typodermic-public-domain
      cardo # Large Unicode font for linguistics
      carlito # Calibri clone
      charis-sil # Broad multilingual use
      comic-relief # Comic Sans clone
      comic-mono
      cooper # Classis serif font
      dinish # DIN roadway signs
      dotcolon-fonts
      edukai # Chinese
      eduli # Chinese
      #broken edusong # Chinese
      encode-sans
      excalifont # Handwriting
      fira-code
      fira-go
      fira-math
      fira-sans
      fixedsys-excelsior
      garamond-libre
      geist-font
      gelasio # Georgia clone
      glasstty-ttf # VT220 font
      goudy-bookletter-1911
      intel-one-mono
      league-of-moveable-type
      monaspace
      monoid
      montserrat
      newcomputermodern
      ocr-a
      overpass # Highway Gothic clone
      pecita
      quicksand
      quivira # 11k+ character Unicode font
      rubik
      scientifica # 4px wide
      sn-pro
      stix-two
      sudo-font
      unifont
      vista-fonts
      weather-icons
      xkcd-font
    ] ++ lib.imap lib.setPrio [
      # Bitmap fonts
      # They need different priorities because they all provide a fonts.dir file.
      # Really, home-manager should generate new fonts.dir files containing all the installed fonts.
      clearlyU # Unicode font
      spleen # 5x8 bitmap font
      tamzen # bitmap font
      tewi-font # Monaco clone
      uni-vga
      unscii # Computer graphics
    ];
  };
}
