{ config, lib, pkgs, ... }:
let
  user = config.systemd.services.home-assistant.serviceConfig.User;
  group = config.systemd.services.home-assistant.serviceConfig.Group;
  dbName = "hass"; # TODO: Why does `user` cause infinite recursion?
  dbUser = user;
in {
  services.postgresql = {
    enable = true;
    ensureDatabases = [dbName];
    ensureUsers = [{
      name = dbUser;
      ensureDBOwnership = true;
    }];
  };
  systemd.services.home-assistant = {
    after = [
      "postgresql.service"
    ];
    requires = [
      "postgresql.service"
    ];
  };
  services.home-assistant = {
    enable = true;
    extraPackages = python3Packages: with python3Packages; [
      # postgresql support in recorder
      psycopg2
    ];

    extraComponents = [
      "apcupsd"
      "androidtv"
      "androidtv_remote"
      "apple_tv"
      "backup"
      "brother"
      "cast"
      "default_config"
      "device_automation"
      "frontend"
      "http"
      "google_assistant"
      "homekit_controller"
      "ipp"
      "lovelace"
      "met"
      "mikrotik"
      "mjpeg"
      "mobile_app"
      "person"
      "samsungtv"
      "websocket_api"
      "yamaha"
      "yamaha_musiccast"
      "yardian"
      "zone"
      "zwave_js"
    ];

    config = {
      default_config = {};
      homeassistant = {
        unit_system = "us_customary";
        temperature_unit = "F";
        currency = "USD";
        country = "US";
      };
      http = {
        trusted_proxies = [ "::1" "127.0.0.1" ];
        use_x_forwarded_for = true;
      };
      recorder = {
        auto_purge = false;
        db_url = "postgresql://@/${dbName}";
        db_retry_wait = 10; # Wait 10 seconds before retrying
      };
      tts = [
        {
          platform = "google_translate";
        }
      ];
      group = "!include groups.yaml";
      "automation ui" = "!include automations.yaml";
      script = "!include scripts.yaml";
      "scene ui" = "!include scenes.yaml";

      light = [{
        platform = "switch";
        name = "Upstairs Hall Lights";
        entity_id = "switch.upstairs_hall";
      }];

      media_player = [{
        platform = "yamaha";
        name = "RX-V485 64CAB8";
        host = "receiver.comclub.org";
      }];

      sensor = [
        {
          platform = "template";
          sensors.receiver_volume = {
            value_template = ''
              {% if is_state('media_player.rx_v485_64cab8', 'on')  %}
              {% set n = states.media_player.rx_v485_64cab8.attributes.volume_level|float %}
              {{ '%.1f'%( (-1.0+n)*100.0|round(0.0) ) }}
              {% else %}
              -80.0
              {% endif %}'';
          friendly_name = "Receiver Volume Level";
          unit_of_measurement = "dB";
          };
        }
      ];
    };
  };
  services.udev.rules = [
    {
      SUBSYSTEM = "tty";
      "ATTRS{idVendor}" = "0658";
      "ATTRS{idProduct}" = "0200";
      RUN = { op = "+="; value = "${pkgs.coreutils}/bin/ln -f $devnode /dev/ttyZwave"; };
    }
  ];
  services.zwave-js-ui = {
    enable = true;
    serialPort = "/dev/ttyZwave";
    settings.HOME = "%t/zwave-js-ui";
    settings.BACKUPS_DIR = "%S/zwave-js-ui/backups";
  };
  systemd.services.zwave-js-ui = let
    deps = ["modprobe@cdc_acm.service"];
  in {
    wants = deps;
    after = deps;
    serviceConfig.BindReadOnlyPaths = [
      "/etc/resolv.conf"
    ];
    serviceConfig.RestrictAddressFamilies = lib.mkForce "AF_INET AF_INET6 AF_NETLINK";
  };
  services.nginx = {
    upstreams.homeassistant.servers."[::1]:${toString config.services.home-assistant.config.http.server_port}" = {};
    upstreams.zwave.servers."127.0.0.1:8091" = {};
    virtualHosts = {
      "homeassistant.comclub.org" = lib.mkIf config.services.home-assistant.enable {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/".tryFiles = "$uri @hass";
          "@hass" = {
            proxyPass = "http://homeassistant";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
          "/zwave/" = {
            proxyPass = "http://zwave";
            proxyWebsockets = true;
            extraConfig = ''
              rewrite ^ $request_uri;
              rewrite '^/zwave(/.*)$' $1 break;
              proxy_set_header X-External-Path /zwave;
            '';
          };
        };
      };
    };
  };
}
