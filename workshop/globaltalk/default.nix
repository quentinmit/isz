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
    };
  };
}
