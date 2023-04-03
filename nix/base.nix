{ lib, pkgs, config, nix-index-database, home-manager, sops-nix, ... }:
{
  imports = [
    ./modules/base
    ./sshd.nix
    home-manager.nixosModules.home-manager
    sops-nix.nixosModules.sops
  ];
  config = {
    i18n.defaultLocale = "en_US.UTF-8";

    hardware.enableAllFirmware = true;

    networking.domain = "isz.wtf";

    environment.systemPackages = with pkgs; [
      ms-sys
      efibootmgr
      efivar
      parted
      gptfdisk
      cryptsetup

      fuse
      fuse3

      sdparm
      hdparm
      usbutils
      nvme-cli

      drm_info
      exfatprogs
      input-utils
      iotop
      psmisc
      strace
      sysstat
      v4l-utils

      # System daemons/parts
      bridge-utils
      cpuset
      i2c-tools
      iptables
      lm_sensors
      util-linux # already present
      net-snmp
      vlan
      netcat-openbsd
    ];
    services.locate.enable = true;
    services.locate.locate = pkgs.mlocate;
    services.locate.localuser = null;
    programs.mtr.enable = true;
    programs.wireshark.enable = true;
    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    programs.ssh.extraConfig = lib.mkIf ((builtins.compareVersions config.programs.ssh.package.version "9.2p1") >= 0) ''
      EnableEscapeCommandline yes
    '';
    programs.git.enable = true;

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.root = {
      home.stateVersion = "22.11";
      programs.home-manager.enable = true;
      # ~/.gitconfig and ~/.config/git/ignore
      programs.git = {
        enable = true;
        ignores = [
          "*~"
        ];
        userName = "Quentin Smith";
        userEmail = "quentin@mit.edu";
        aliases = {
          up = "pull --rebase";
          k = "log --graph --abbrev-commit --pretty=oneline --decorate";
        };
      };
      programs.bash = rec {
        enable = true;
        historyFileSize = 100000;
        historySize = historyFileSize;
        shellAliases = {
          nix-diff-system = "${pkgs.nix-diff}/bin/nix-diff $(nix-store -qd $(ls -dtr /nix/var/nix/profiles/*-link | tail -n 2))";
        };
      };
      programs.nix-index = {
        enable = true;
        enableBashIntegration = true;
      };
      # Configure emacs
      home.file.".emacs".source = pkgs.writeTextFile {
        name = "emacs";
        text = ''
          (custom-set-variables
           ;; custom-set-variables was added by Custom.
           ;; If you edit it by hand, you could mess it up, so be careful.
           ;; Your init file should contain only one such instance.
           ;; If there is more than one, they won't work right.
           ; '(gofmt-command "goimports")
           '(ido-mode (quote both) nil (ido))
          )
          (custom-set-faces
           ;; custom-set-faces was added by Custom.
           ;; If you edit it by hand, you could mess it up, so be careful.
           ;; Your init file should contain only one such instance.
           ;; If there is more than one, they won't work right.
           )
          (setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")
          (defun go-mode-setup ()
           ;;(go-eldoc-setup)
           ; (add-hook 'before-save-hook 'gofmt-before-save)
          )
          (add-hook 'go-mode-hook 'go-mode-setup)
        '';
      };
    };
  };
}
