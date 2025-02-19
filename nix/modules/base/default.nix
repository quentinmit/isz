{ lib, pkgs, config, nix-index-database, home-manager, sops-nix, self, ... }:
{
  imports = [
    ./common.nix
    home-manager.nixosModules.home-manager
    sops-nix.nixosModules.sops
  ];
  config = {
    environment.systemPackages = with pkgs; [
      man-pages
      man-pages-posix
    ];
    i18n.defaultLocale = "en_US.UTF-8";

    hardware.enableAllFirmware = true;

    networking.domain = "isz.wtf";

    nix.registry.isz.flake = self;

    services.locate.enable = true;
    services.locate.package = pkgs.mlocate;
    services.locate.localuser = lib.mkIf (lib.versionOlder lib.version "25.05") null;

    programs.mtr.enable = true;

    programs.wireshark.enable = true;

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    programs.ssh.extraConfig = lib.mkIf ((builtins.compareVersions config.programs.ssh.package.version "9.2p1") >= 0) ''
      EnableEscapeCommandline yes
    '';

    programs.git.enable = true;

    users.users."root".openssh.authorizedKeys.keys = [
      "ssh-dss AAAAB3NzaC1kc3MAAACBAKkmA85sGJjOMkH0lYj1apiCyvyBtKYJcM3sBn4lBrDV59E1FzgE2SvNnysgHVjVJtrqzt9AbYShDggAOgH3uSoc8wppETurUeTTiS59Y0WzWIHNTEAcsKvQw+2Zj3pU0vYU01cUhm2iV9Cw49gf7VwRtCoavVzsQaHMDWq4vMbpAAAAFQCtpPp74y1vTh14Z8I4/bO1/kWCNwAAAIBGCm5M6envG4iojPor4gXAIsZdlHVK/RNSl6jmisuMnx8a/e8H45LCBmEDYY7px8sSgSt85x6p6qd2UsPI1vHxd945PTKjbpiRNoCifKEBdKLVueYo2jlBIgKRYKJ4oMvyxFGuzaaMokO2AVlmeFjnQF4qIV6G2PhRIJ6+l+j3qAAAAIEAi5F+CBVmOvwazgI9aDmNXr+29Y6L7QW4EmA0pFiQG/aPhI37SeaArf7+/v2XSZMzqNa2VNiu8pDCUngU5YdZLb5DoHTSx4W5j3hgT5ken4WYd8SxxA5A/PEzLbZcEBiml5EN3EA/yymtyv34CzV5waOvyg80khraulngix5r2sY= quentins@209.177.24.26.dhcp.lightlink.com"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCUtRBFYPQ0OicLdAVNJih4JZp0JsGnKM/jRnG4GzGGW/bvNYtcNRCNWKHkMKAZvHSxLw8H3UVDDpyYWPnCw75rSR9aAIOVMAa4ScQyBKPvPNEM55XQT+AW8oapeSDkVrvhxJpLf8vCBz0jx15meQgQm9T/CnmHnigojcGbxtwe8znL2VQoZZnrd9KW69a94CEQuJZAKIur0Y00NoMuZYhgRFQMmuxXlqlwJSohTPHziHUxLpp/oqHnwh6er7bZwHfw7pBwSrwOyd4z4P1uWwJf2G0ShpVR07HtTtHLWIR+08ms0MiRpkgdPNFc4M9vlG4ZwOUVEuyJbJIj9VZIssLehKXXvOFj6nFqGTgMfflxd5vuS4bPJd2wRJymi+LXFMZcrg/8q8+6FJqUlp46hC3gR8iYQpLHQ4vpZgjNXncm5hAJsKDzQMrpHHkjR4jMibqsSMTHFNdXgzu4lZ2U/bxz33dEA/hOWmoWKK+zh6fjtRdMgT2ygnbVCrDtRW8zlmD4g88c1a02slOnK4tnM8XQ8xHP+n6cGfrwM1vCpNtxGWTrt+DvfTLhJhB74VTNYc4cLAQQf1d+k+wjjreswMCmLC8scmoyRqkhvEqatoRqQaeo9DG8OTUSZnmezZX4r5cF+fOsKbFRzAwKDBQqeA8oW6egTVNNxpQDOBUrrlopCw== quentin@GREEN-SEVEN-FIFTY.MIT.EDU"
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsGMP08Nq2dliWfi3WnODNuaOrRUNuRegwC81atTgeNSndkYsgCXEPthiDrjRd2vpM06R4sMLAPUmvXQyEr8QqR+TUwrJq2eghhBycNXChXdPd9ahaSMsWReoyyRqc32OPidF6p/t9Rd+SAAAF6a+skcoV8Nu1HgGwMNe7ByuOub6HGTdvTo13PTuAlugcEhDfakaMkxZ41kXQbT5xPOWhKQY2vfZaC35gd86rPqM9Ols+4wEaByFXijsbWmEOr4wJmOfe4hWnO9sQFsC9oOrFBRd/XipQnMg522cepIY7nVMPi5UDYEe8O5dgs+7GrIKxWcwzdglBgE0nYp8xp6BDw== quentin@quentin-macbookpro.cam.corp.google.com"
    ];

    home-manager.users.root = {
      home.stateVersion = "23.05";

      isz.base = true;

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
