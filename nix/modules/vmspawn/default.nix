{ pkgs, config, lib, ... } @ host:
let
  cfg = config.systemd.vmspawn;
in {
  options = with lib; {
    systemd.vmspawn = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable systemd-vmspawn";
      };
    };
    vms = mkOption {
      default = {};
      type = types.attrsOf (
        types.submodule (
          {
            config,
            options,
            name,
            ...
          }:
          {
            options = {
              config = mkOption {
                type = lib.mkOptionType {
                  name = "Toplevel NixOS config";
                  merge =
                    loc: defs:
                    (import "${toString config.nixpkgs}/nixos/lib/eval-config.nix" {
                      modules =
                        let
                          extraConfig =
                            { options, ... }:
                            {
                              _file = "module at ${__curPos.file}:${toString __curPos.line}";
                              imports = [
                                ./vmconfig.nix
                              ];
                              config = {
                                nixpkgs =
                                  if options.nixpkgs ? hostPlatform then
                                    { inherit (host.pkgs.stdenv) hostPlatform; }
                                  else
                                    { localSystem = host.pkgs.stdenv.hostPlatform; };
                                networking.hostName = mkDefault name;
                                assertions = [
                                  {
                                    assertion = !lib.strings.hasInfix "_" name;
                                    message = ''
                                    Names containing underscores are not allowed in vmspawn VMs. Please rename the VM '${name}'
                                  '';
                                  }
                                ];
                                fileSystems."/nix/store" =
                                  if config.writableStore then
                                    {
                                      overlay = {
                                        lowerdir = [ "/nix/.ro-store" ];
                                        upperdir = "/nix/.rw-store/upper";
                                        workdir = "/nix/.rw-store/work";
                                      };
                                      options = [ "userxattr" ];
                                    }
                                  else
                                    {
                                      device = "/nix/.ro-store";
                                      options = [ "bind" ];
                                    };

                                fileSystems."/nix/.ro-store" = {
                                  device = "mnt0";
                                  fsType = "virtiofs";
                                  neededForBoot = true;
                                };
                              };
                            };
                        in
                          [ extraConfig ] ++ (map (x: x.value) defs);
                      prefix = [
                        "vms"
                        name
                      ];
                      inherit (config) specialArgs;

                      # The system is inherited from the host above.
                      # Set it to null, to remove the "legacy" entrypoint's non-hermetic default.
                      system = null;
                    }).config;
                };
              };
              nixpkgs = mkOption {
                type = types.path;
                default = pkgs.path;
                defaultText = literalExpression "pkgs.path";
                description = ''
                  A path to the nixpkgs that provide the modules, pkgs and lib for evaluating the container.

                  To only change the `pkgs` argument used inside the container modules,
                  set the `nixpkgs.*` options in the container {option}`config`.
                  Setting `config.nixpkgs.pkgs = pkgs` speeds up the container evaluation
                  by reusing the system pkgs, but the `nixpkgs.config` option in the
                  container config is ignored in this case.
                '';
              };
              specialArgs = mkOption {
                type = types.attrsOf types.unspecified;
                default = { };
                description = ''
                  A set of special arguments to be passed to NixOS modules.
                  This will be merged into the `specialArgs` used to evaluate
                  the NixOS configurations.
                '';
              };
              writableStore = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  If enabled, the Nix store in the VM is made writable by
                  layering an overlay filesystem on top of the host's Nix
                  store.
                '';
              };
              extraFlags = mkOption {
                type = types.listOf types.str;
                default = [];
                description = ''
                  Extra flags to passed to the systemd-vmspawn command.
                '';
              };
            };
          }
        )
      );
    };
  };
  config = lib.mkMerge [
    {
      systemd.vmspawn.enable = lib.mkIf (config.vms != {}) true;
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.qemu_kvm
        pkgs.swtpm
        pkgs.virtiofsd
      ];
      # This allows vmspawn to find and enumerate firmwares
      environment.etc."qemu/firmware".source = "${pkgs.qemu_kvm}/share/qemu/firmware";
      systemd.additionalUpstreamSystemUnits = lib.mkIf (lib.versionAtLeast config.systemd.package.version "256") [
        "systemd-vmspawn@.service"
      ];
      systemd.additionalUpstreamUserUnits = lib.mkIf (lib.versionAtLeast config.systemd.package.version "258") [
        "systemd-vmspawn@.service"
      ];
      systemd.services = lib.mapAttrs' (name: cfg: let
        root = cfg.config.system.build.toplevel;
      in lib.nameValuePair "systemd-vmspawn@${name}" {
        overrideStrategy = "asDropin";
        path = with pkgs; [
          qemu
          virtiofsd
          openssh
        ];
        serviceConfig = {
          StateDirectory = "machines/%i";
          TimeoutSec = "5min";
          WatchdogSec = "6min";
          ExecStart = [
            ""
            "${lib.getExe' pkgs.systemd "systemd-vmspawn"} --directory=/var/lib/machines/%i --register=yes --keep-unit --network-tap --machine=%i --bind-ro=/nix/store:/nix/.ro-store ${lib.escapeShellArgs cfg.extraFlags} --linux=${root}/kernel --initrd=${root}/initrd ${root}/kernel-params init=${root}/init regInfo=${pkgs.closureInfo { rootPaths = [ cfg.config.system.build.toplevel ]; }}/registration"
          ];
        };
      }) config.vms;
    })
  ];
}
