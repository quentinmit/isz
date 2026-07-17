{ config, pkgs, lib, ... }:
let
  inherit (config.security.pki) caBundle;
  sslCertDir = config.security.acme.certs."mail.isz.wtf".directory;
  domainName = "isz.wtf";
in {
  services.nginx.virtualHosts."mail.isz.wtf".enableACME = true;
  sops.secrets."authentik/apps/dovecot/client_id" = {};
  sops.secrets."authentik/apps/dovecot/client_secret" = {};
  services.authentik.apps.dovecot = {
    name = "Dovecot";
    type = "oauth2";
    redirect_uris = [
      {
        matching_mode = "regex";
        url = "^http://localhost:\\d+/.*";
      }
    ];
    properties = [
      "goauthentik.io/providers/oauth2/scope-email"
    ];
    groups = [
      "Residents"
    ];
  };
  sops.templates."dovecot-oauth2_introspection_url".content =
    ''https://${config.sops.placeholder."authentik/apps/dovecot/client_id"}:${config.sops.placeholder."authentik/apps/dovecot/client_secret"}@auth.isz.wtf/application/o/introspect/'';
  services.dovecot2 = {
    enable = true;

    enablePAM = false;

    package = pkgs.dovecot; # Dovecot 2.4

    # https://integrations.goauthentik.io/chat-communication-collaboration/roundcube/
    settings = {
      dovecot_config_version = "2.4.2";
      dovecot_storage_version = "2.4.0";

      protocols.imap = true;
      protocols.lmtp = true;

      ssl_server = {
        cert_file = "${sslCertDir}/cert.pem";
        key_file = "${sslCertDir}/key.pem";
        ca_file = "${sslCertDir}/chain.pem";
      };

      log_debug = "category=auth";
      auth_verbose = true;

      auth_mechanisms = ["plain" "login" "oauthbearer" "xoauth2"];

      mdbox_rotate_size = "64M";

      default_vsz_limit = "8G";

      mail_driver = "mdbox";
      mail_path = "/var/lib/dovecot/mdbox/%{user | domain}/%{user | username}";

      "userdb passwd-file" = [
        {
          driver = "passwd-file";
          passwd_file_path = "/etc/passwd";
          auth_username_format = "%{user | username | lower}";
        }
      ];

      "passdb passwd-file" = [
        {
          driver = "passwd-file";
          auth_username_format = "%{user | username | lower}";
          passwd_file_path = "/etc/dovecot/auth/%{user | domain | lower}/passwd";
        }
      ];

      "passdb oauth2" = [
        {
          driver = "oauth2";
          mechanisms_filter = ["xoauth2" "oauthbearer"];
        }
      ];
      oauth2 = {
        tokeninfo_url = "https://auth.isz.wtf/application/o/userinfo/?access_token=";
        introspection_url = "<${config.sops.templates."dovecot-oauth2_introspection_url".path}";
        introspection_mode = "post";
        force_introspection = true;
        active_attribute = "active";
        active_value = "true";
        username_attribute = "email";
        ssl_client_ca_file = "/etc/ssl/certs/ca-certificates.crt";
      };
    };
  };

  sops.secrets."xoauth2/o365/tenant_id" = {};
  sops.secrets."xoauth2/o365/client_id" = {};
  sops.secrets."xoauth2/o365/client_secret" = {};
  sops.templates."oauth2ms-config.json" = {
    owner = "quentin";
    content = builtins.toJSON {
      tenant_id = config.sops.placeholder."xoauth2/o365/tenant_id";
      client_id = config.sops.placeholder."xoauth2/o365/client_id";
      client_secret = config.sops.placeholder."xoauth2/o365/client_secret";
      redirect_host = "localhost";
      redirect_port = "7000";
      redirect_path = "/getToken/";
      scopes = [
        "https://outlook.office.com/IMAP.AccessAsUser.All"
        "https://outlook.office.com/SMTP.Send"
      ];
    };
  };
  isz.krb5.enable = true;
  home-manager.users.quentin = let
    isync = pkgs.isync.override {
        withCyrusSaslXoauth2 = true;
      };
    nixosConfig = config;
  in { config, ... }: {
    home.packages = [
      isync
      pkgs.oauth2ms
    ];
    xdg.configFile."oauth2ms/config.json".source = config.lib.file.mkOutOfStoreSymlink nixosConfig.sops.templates."oauth2ms-config.json".path;
    home.file.".mbsyncrc".text = ''
      IMAPAccount mit
      Host outlook.office365.com
      Port 993
      User quentin@mit.edu
      PassCmd ${lib.getExe pkgs.oauth2ms}
      AuthMechs XOAUTH2
      TLSType IMAPS
      # It can be very, very slow.
      Timeout 600

      IMAPStore mit-remote
      Account mit

      MaildirStore mit-local
      Path /home/quentin/Maildir/MIT/
      Inbox /home/quentin/Maildir/MIT/INBOX
      SubFolders Verbatim

      IMAPAccount dovecot
      Host mail.isz.wtf
      Port 993
      User quentin@isz.wtf
      PassCmd "systemd-creds decrypt --user --name= ${./dovecot-quentin.creds}"
      AuthMechs login plain
      TLSType IMAPS

      IMAPStore dovecot
      Account dovecot

      Channel mit2maildir
      Far :mit-remote:
      Near :mit-local:
      Expunge none
      CopyArrivalDate yes
      Sync pull
      Create near

      Channel mit
      Far :mit-remote:
      Near :dovecot:MIT
      #Patterns Archive Drafts SentItems DeletedItems JunkEmail INBOX
      Expunge none
      #Expunge both
      CopyArrivalDate yes
      Sync pull
      Create near
    '';
    services.mbsync = {
      enable = false;
      package = isync;
    };
    programs.msmtp = {
      enable = true;
    };
    programs.alpine.extraConfig.sendmail-path = "${lib.getExe pkgs.msmtp} --read-envelope-from --read-recipients";
    accounts.email.accounts.mit = {
      realName = "Quentin Smith";
      address = "quentin@mit.edu";
      userName = "quentin@mit.edu";
      smtp.host = "outgoing.mit.edu";
      smtp.port = 587;
      smtp.tls.enable = true;
      smtp.tls.useStartTls = true;
      smtp.tls.certificatesFile = caBundle;
      msmtp.enable = true;
      msmtp.extraConfig.auth = "gssapi";
      # passwordCommand = lib.getExe pkgs.oauth2ms;
      # smtp.host = "smtp.office365.com";
      # msmtp.extraConfig = {
      #   tls_certcheck = "on";
      #   auth = "xoauth2";
      # };
    };
  };
}
