{ config, pkgs, lib, ... }:

{
  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "25.05";

      isz.base = true;
    }
    {
      programs.alpine = {
        enable = true;
        extraConfig = {
          pruning-rule = "no-no";
          alt-addresses = [
            "quentin@mit.edu"
          ];
          incoming-folders = [
            "MIT {mail.isz.wtf}MIT"
          ];
          folder-collections = [
            "mail/[]"
            "Maildir #md/Maildir/[]"
            "ISZ {mail.isz.wtf}[]"
          ];
          customized-hdrs = [
            "Reply-To:"
          ];
          character-set = "UTF-8";
          editor = "emacs";
          # TODO: display-filters for pgp4pine
          url-viewers = [
            "${pkgs.writeShellScript "display-qr" ''
              ${lib.getExe pkgs.qrrs} "$@"
              echo
              echo "$@"
              echo
              echo "Press enter to continue"
              read
            ''}"
            "${lib.getExe pkgs.links2}"
          ];
          address-book = "AB .addressbook";
          # TODO: sendmail-path
          # TODO: printer
          # TODO: patterns-roles
        };
        features = {
          alternate-compose-menu = true;
          convert-dates-to-localtime = true;
          enable-aggregate-command-set = true;
          enable-alternate-editor-cmd = true;
          enable-arrow-navigation = true;
          enable-arrow-navigation-relaxed = true;
          enable-bounce-cmd = true;
          enable-flag-cmd = true;
          enable-incoming-folders = true;
          enable-mouse-in-xterm = true;
          enable-partial-match-lists = true;
          enable-suspend = true;
          enable-tab-completion = true;
          enable-unix-pipe-cmd = true;
          expose-hidden-config = true;
          print-index-enabled = true;
          print-offers-custom-cmd-prompt = true;
          quell-full-header-auto-reset = true;
          show-sort = true;
          signature-at-bottom = true;
          warn-if-blank-subject = true;

          auto-zoom-after-select = false;
          delete-skips-deleted = false;
          disable-keymenu = false;
        };
      };
    }
  ];
}
