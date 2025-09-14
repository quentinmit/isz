{ config, pkgs, lib, self, specialArgs, ... }:
{
  systemd.network.networks."20-ve-rtorrent" = {
    name = "ve-rtorrent";
    networkConfig = {
      LinkLocalAddressing = "ipv6";
      LLDP = true;
      #EmitLLDP=customer-bridge
      IPv6AcceptRA = false;
      IPv6SendRA = false;
    };
  };
  systemd.services."container@rtorrent" = let
    requires = ["home-quentin-hog\\x2ddata.mount"];
  in {
    inherit requires;
    after = requires;
  };

  security.polkit = {
    debug = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id === "org.freedesktop.machine1.shell") {
          const machine = action.lookup("machine");
          polkit.log("user " + subject.user + " requesting machine " + machine);
          if (machine === "rtorrent" && subject.user === "quentin") {
            return polkit.Result.YES;
          }
          polkit.log("action=" + action);
          polkit.log("subject=" + subject);
        }
      });
    '';
  };

  containers.rtorrent = {
    privateNetwork = true;
    extraFlags = [
      "--network-veth"
    ];
    bindMounts."/srv/private" = {
      hostPath = "/home/quentin/hog-data/quentin/private/";
      mountPoint = "/srv/private";#:owneridmap";
      isReadOnly = false;
    };
    inherit specialArgs;
    config = { config, pkgs, lib, ... }: {
      imports = [
        self.overlayModule
        self.nixosModules.base
      ];
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      networking.firewall.enable = false;

      system.stateVersion = "24.11";

      security.pam.loginLimits = [
        {
          domain = "*";
          type = "-";
          item = "nofile";
          value = "8192";
        }
      ];

      users.users.quentin = {
        isNormalUser = true;
        description = "Quentin Smith";
      };

      home-manager.users.quentin = lib.mkMerge [
        {
          home.stateVersion = "24.05";

          isz.base = true;
        }
        # rtorrent
        {
          home.packages = with pkgs; [
            pyrosimple
          ];
          programs.rtorrent = {
            enable = true;
            package = pkgs.unstable.rtorrent;
            extraConfig = ''
              upload_rate = 1000
              port_random = yes
              dht.mode.set = auto
              dht_port = 6882
              #network.local_address.set = "127.0.0.1"

              # Per-torrent slots (default 50/50)
              throttle.max_uploads.set = 100
              throttle.max_downloads.set = 100

              # Define a new throttle class called 10K
              throttle.up = 10K, 10

              protocol.encryption.set = allow_incoming,try_outgoing,enable_retry

              # Limits for file handle resources, this is optimized for
              # an `ulimit` of 1024 (a common default). You MUST leave
              # a ceiling of handles reserved for rTorrent's internal needs!
              # Default 32, sample 50
              network.http.max_open.set = 100
              # Default 128, sample 600
              network.max_open_files.set = 1000
              # Default 768, sample 300
              network.max_open_sockets.set = 1000

              # Memory resource usage (increase if you have a large number of items loaded,
              # and/or the available resources to spend)
              # Default 3276M, sample 1800M
              pieces.memory.max.set = 4096M
              # Default 16M, sample 4M
              network.xmlrpc.size_limit.set = 16M

              # Basic operational settings
              session = /srv/private/rtorrent-session
              method.insert = cfg.logs,    private|const|string, (cat,(session.path),"log/")
              method.insert = cfg.logfile, private|const|string, (cat,(cfg.logs),"rtorrent-",(system.time),".log")
              execute.throw = bash, -c, (cat, "mkdir -p ", (session.path), "log/")
              log.execute = (cat, (cfg.logs), "execute.log")
              execute.nothrow = bash, -c, (cat, "echo >",\
                  (session.path), "rtorrent.pid", " ", (system.pid))

              # Other operational settings (check & adapt)
              encoding.add = UTF-8
              # Default 60
              network.http.dns_cache_timeout.set = 25
              # Default yes
              pieces.hash.on_completion.set = no
              #network.rpc.use_xmlrpc.set = true
              #network.rpc.use_jsonrpc.set = true

              ## Some additional values and commands
              method.insert = system.startup_time, value|const, (system.time)
              method.insert = d.data_path, simple,\
                  "if=(d.is_multi_file),\
                      (cat, (d.directory), /),\
                      (cat, (d.directory), /, (d.name))"
              method.insert = d.session_file, simple, "cat=(session.path), (d.hash), .torrent"

              network.scgi.open_local = (cat,(session.path),rpc.socket)
              #execute.nothrow = chmod,770,(cat,(session.path),rpc.socket)

              ## Logging:
              ##   Levels = critical error warn notice info debug
              ##   Groups = connection_* dht_* peer_* rpc_* storage_* thread_* tracker_* torrent_*
              print = (cat, "Logging to ", (cfg.logfile))
              log.open_file = "log", (cfg.logfile)
              log.add_output = "info", "log"
              #log.add_output = "tracker_debug", "log"

              # VIEW: Use rtcontrol filter (^X s=KEYWORD, ^X t=TRACKER, ^X f="FILTER")
              method.insert = s,simple|private,"execute.nothrow=rtcontrol,--detach,-qV,\"$cat=*,$argument.0=,*\""
              method.insert = t,simple|private,"execute.nothrow=rtcontrol,--detach,-qV,\"$cat=\\\"alias=\\\",$argument.0=\""
              method.insert = f,simple|private,"execute.nothrow=rtcontrol,--detach,-qV,$argument.0="
            '';
          };
          xdg.configFile."pyrosimple/config.toml".source = (pkgs.formats.toml {}).generate "pyrosimple.toml" {
            rtorrent_rc = "~/.config/rtorrent/rtorrent.rc";
            scgi_url = "/srv/private/rtorrent-session/rpc.socket";
            fast_query = 1;
          };
        }
        {
          home.packages = with pkgs; [
            irssi
          ];
        }
      ];
    };
  };
}
