{ config, pkgs, lib, ... }:
let
  sslCertDir = config.security.acme.certs."mail.isz.wtf".directory;
  domainName = "isz.wtf";
in {
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

    enablePAM = false;

    mailLocation = "mdbox:/var/lib/dovecot/mdbox/%d/%n";

    # https://integrations.goauthentik.io/chat-communication-collaboration/roundcube/
    extraConfig = ''
      auth_debug = yes
      auth_verbose = yes

      auth_mechanisms = oauthbearer xoauth2

      passdb {
        driver = oauth2
        mechanisms = xoauth2 oauthbearer
        args = ${config.sops.templates."dovecot-oauth.conf.ext".path}
      }
    '';
  };
  home-manager.users.quentin = let
    isync = pkgs.isync.override {
        withCyrusSaslXoauth2 = true;
      };
  in {
    home.packages = [ isync ];
    home.file.".mbsyncrc".text = ''
      
    '';
    services.mbsync = {
      enable = false;
      package = isync;
    };
  };
}
