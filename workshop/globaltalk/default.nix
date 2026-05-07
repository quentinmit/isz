{ config, pkgs, lib, self, specialArgs, ... }:
{
  imports = [
    ./router.nix
  ];

  boot.extraModulePackages = [((pkgs.callPackage ../../nix/kernel-module.nix {
    inherit (config.boot.kernelPackages) kernel;
    modulePath = "net/appletalk";
  }).overrideAttrs {
    patches = [
      ./atalk-namespace.patch
    ];
  })];

  environment.systemPackages = with pkgs; [
    vdeplug4
  ];

  systemd.network.networks."20-atalk" = {
    name = "atalk-*";
    networkConfig = {
      Bridge = "br0";
    };
    bridgeVLANs = [
      { PVID = 983; EgressUntagged = 983; }
    ];
  };

  systemd.network.networks."20-ve-globaltalk" = {
    name = "ve-globaltalk";
    networkConfig = {
      Bridge = "br0";
    };
    bridgeVLANs = [
      { PVID = 983; EgressUntagged = 983; }
    ];
  };

  security.polkit = {
    debug = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id === "org.freedesktop.machine1.shell") {
          const machine = action.lookup("machine");
          polkit.log("user " + subject.user + " requesting machine " + machine);
          if (machine === "globaltalk" && subject.user === "quentin") {
            return polkit.Result.YES;
          }
          polkit.log("action=" + action);
          polkit.log("subject=" + subject);
        }
      });
    '';
  };

  containers.globaltalk = {
    autoStart = true;
    restartIfChanged = false;
    privateNetwork = true;
    extraFlags = [
      "--network-veth"
    ];
    inherit specialArgs;
    config = { config, pkgs, lib, ... }: {
      imports = [
        self.overlayModule
        self.nixosModules.base
        self.nixosModules.papd
      ];
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      networking.firewall.enable = false;

      systemd.network.networks."20-host0" = {
        matchConfig = {
          Kind = "veth";
          Name = "host0";
          Virtualization = "container";
        };
        networkConfig = {
          Address = "172.30.98.131/26";
          Gateway = "172.30.98.129";
          DNS = "172.30.98.129";
        };
      };

      system.stateVersion = "25.11";

      services.atalkd = {
        enable = true;
        interfaces.host0.config = ''-phase 2 -net 1520 -addr 1520.142 -zone "ISZ"'';
      };
      # services.atalkd.enable adds a dependency on sys-subsystem-net-devices-host0.device, but that doesn't exist in a container.
      systemd.services.atalkd.requires = lib.mkForce [];
      systemd.services.netatalk.requires = lib.mkForce [];

      users.users.afpguest = {
        isSystemUser = true;
        group = "afpguest";
      };
      users.groups.afpguest = {};
      services.netatalk = {
        enable = true;
        settings = {
          Global = {
            appletalk = true;
            afpstats = true;
            "server name" = "workshop";
            "uam list" = "uams_guest.so";
            "legacy icon" = "daemon";
            "guest account" = "afpguest";
          };
          Dropbox = {
            "volume name" = "Dropbox";
            path = "/srv/dropbox";
            "read only" = false;
            "cnid scheme" = "dbd";
            "legacy volume size" = true;
          };
        };
      };

      systemd.tmpfiles.settings."10-pdf" = {
        "/var/spool/pdf".d = {
          user = "cups";
          group = "root";
          mode = "0755";
        };
      };

      nixpkgs.overlays = [(final: prev: {
        netatalk = prev.netatalk.overrideAttrs (old: {
          postPatch = old.postPatch or "" + ''
            substituteInPlace etc/papd/meson.build \
              --replace-fail "' + spooldir" "/' + spooldir"
          '';
        });
      })];

      fonts = {
        enableDefaultFonts = true;
        enableGhostscriptFonts = true;
      };

      services.printing = let
        pdfBackend = pkgs.writeShellApplication {
          name = "../lib/cups/backend/pdf";
          # Based on https://wiki.alienbase.nl/doku.php?id=slackware:cups
          runtimeInputs = with pkgs; [
            ghostscript
            coreutils
          ];
          text = ''
            set -x
            PDFBIN="ps2pdf"
            # filename of the PDF File
            PRINTTIME=$(date +%Y-%m-%d_%H.%M.%S)
            # no argument, prints available URIs
            if [ $# -eq 0 ]; then
              echo "direct pdf \"Unknown\" \"PDF Creator\""
              exit 0
            fi
            # case of wrong number of arguments
            if [ $# -ne 5 ] && [ $# -ne 6 ]; then
              echo "Usage: pdf job-id user title copies options [file]"
              exit 1
            fi
            # get PDF directory from device URI, and check write status
            PDFDIR=''${DEVICE_URI#pdf:}
            if [ ! -d "$PDFDIR" ] || [ ! -w "$PDFDIR" ]; then
              echo "ERROR: directory $PDFDIR not writable"
              exit 1
            fi
            # generate output filename
            OUTPUTFILENAME=
            if [ "$3" = "" ]; then
              OUTPUTFILENAME="$PDFDIR/unknown.pdf"
            else
              if [ "$2" != "" ]; then
                OUTPUTFILENAME="$PDFDIR/$2-$PRINTTIME.pdf"
              else
                OUTPUTFILENAME="$PDFDIR/$PRINTTIME.pdf"
              fi
            fi
            # run ghostscript
            if [ $# -eq 6 ]; then
              $PDFBIN "$6" "$OUTPUTFILENAME" >& /dev/null
            else
              $PDFBIN - "$OUTPUTFILENAME" >& /dev/null
            fi

            # Make the file visible (but read-only except for owner);
            # This is only needed when the username ($2) is not set,
            # for instance when printing a test page from the web interface.
            chmod 644 "$OUTPUTFILENAME"

            exit 0
          '';
        };
      in {
        enable = true;
        drivers = with pkgs; [
          gutenprint
          foomatic-db-ppds
          cups-pdf-to-pdf
          pdfBackend
        ];
      };
      hardware.printers.ensurePrinters = [{
        name = "PDF";
        deviceUri = "pdf:/var/spool/pdf/";
        model = "CUPS-PDF_noopt.ppd";
        ppdOptions.job-sheets-default = "standard";
      }];
      services.papd = {
        enable = true;
        printers."GlobalTalk PDF Printer" = {
          operator = "afpguest";
          printer = "PDF";
        };
      };
    };
  };
}
