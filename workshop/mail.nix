{ config, pkgs, lib, ... }:
let
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
  sops.templates."dovecot-oauth.conf.ext".content = ''
    tokeninfo_url = https://auth.isz.wtf/application/o/userinfo/?access_token=
    introspection_url = https://${config.sops.placeholder."authentik/apps/dovecot/client_id"}:${config.sops.placeholder."authentik/apps/dovecot/client_secret"}@authentik.company/application/o/introspect/
    introspection_mode = post
    force_introspection = yes
    active_attribute = active
    active_value = true
    username_attribute = email
    tls_ca_cert_file = /etc/ssl/certs/ca-certificates.crt
  '';
  services.dovecot2 = {
    enable = true;

    sslServerCert = "${sslCertDir}/cert.pem";
    sslServerKey = "${sslCertDir}/key.pem";
    sslCACert = "${sslCertDir}/chain.pem";

    enablePAM = false;

    mailLocation = "mdbox:/var/lib/dovecot/mdbox/%d/%n";

    # https://integrations.goauthentik.io/chat-communication-collaboration/roundcube/
    extraConfig = ''
      auth_debug = yes
      auth_verbose = yes

      auth_mechanisms = plain login oauthbearer xoauth2
      auth_verbose = yes
      auth_debug = yes

      mdbox_rotate_size = 64M

      default_vsz_limit = 8G

      userdb {
        driver = passwd-file
        args = username_format=%Ln /etc/passwd
      }

      passdb {
        driver = passwd-file
        args = username_format=%Ln /etc/dovecot/auth/%Ld/passwd
      }

      passdb {
        driver = oauth2
        mechanisms = xoauth2 oauthbearer
        args = ${config.sops.templates."dovecot-oauth.conf.ext".path}
      }
    '';
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
  };
}
