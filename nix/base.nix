{ lib, pkgs, config, nix-index-database, home-manager, sops-nix, ... }:
{
  imports = [
    ./modules/base
    ./sshd.nix
    sops-nix.nixosModules.sops
  ];
  config = {
    i18n.defaultLocale = "en_US.UTF-8";

    hardware.enableAllFirmware = true;

    networking.domain = "isz.wtf";

    environment.systemPackages = with pkgs; [
      # Partition/MBR tools
      ms-sys
      efibootmgr
      efivar
      parted
      gptfdisk

      # Filesystems
      exfatprogs
      fuse
      fuse3

      # Block devices
      sdparm
      hdparm
      nvme-cli
      cryptsetup

      # Other devices
      drm_info
      usbutils
      input-utils
      v4l-utils
      lm_sensors
      i2c-tools

      # Performance tools
      iotop
      psmisc
      strace
      sysstat
      cpuset

      # Networking
      bridge-utils
      iptables
      vlan
      netcat-openbsd

      # Utilities
      util-linux
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

    home-manager.users.root = {
      home.stateVersion = "22.11";

      imports = [
        ./home/base.nix
      ];
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
