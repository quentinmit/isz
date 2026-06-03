{ config, pkgs, ... }:
let
  sslCertDir = config.security.acme.certs."mail.comclub.org".directory;
in {
  services.nginx.virtualHosts."mail.comclub.org".enableACME = true;
  users.users.mail = {
    group = "mail";
    isSystemUser = true;
  };
  users.groups.mail = {};
  services.dovecot2 = {
    enable = true;

    enablePAM = false; # Handled below

    mailPlugins.globally.enable = [
      "acl"
    ];

    mailPlugins.perProtocol.lda.enable = [
      "sieve"
    ];

    settings = {
      ssl_cert = "<${sslCertDir}/cert.pem";
      ssl_key = "<${sslCertDir}/key.pem";
      ssl_ca = "<${sslCertDir}/chain.pem";

      protocols = ["imap" "lmtp"];

      auth_mechanisms = ["plain" "login"];
      auth_verbose = true;
      auth_debug = true;
      #mail_debug = true;

      mdbox_rotate_size = "64M";

      mail_location = "mdbox:~/mdbox";
      mail_privileged_group = "mail";

      "namespace inbox" = {
        inbox = true;
      };
      namespace = [
        {
          type = "shared";
          separator = "/";
          prefix = "shared/%%n/";
          location = "mdbox:%%h/mdbox";
          subscriptions = false;
          list = "children";
        }
        {
          separator = "/";
          prefix = "mail/";
          hidden = true;
          list = false;
          alias_for = "";
        }
        {
          separator = "/";
          prefix = "~/mail/";
          hidden = true;
          list = false;
          alias_for = "";
        }
        {
          separator = "/";
          prefix = "~%u/mail/";
          hidden = true;
          list = false;
          alias_for = "";
        }
      ];

      "service lmtp"."unix_listener /var/lib/postfix/queue/private/dovecot-lmtp" = {
        mode = "0660";
        user = "postfix";
        group = "postfix";
      };
      "service auth"."unix_listener /var/lib/postfix/queue/private/auth" = {
        mode = "0660";
        user = "postfix";
        group = "postfix";
      };
      # Virtual domains
      auth_username_format = "%{if;%Ld;eq;comclub.org;%Ln;%Lu}";
      passdb = [
        {
          driver = "passwd-file";
          # Each domain has a separate passwd-file:
          args = ["scheme=plain-md5" "username_format=%Ln" "/etc/dovecot/auth/%Ld/passwd"];
        }
        {
          driver = "pam";
          args = "dovecot2";
        }
      ];
      userdb = [
        # First try to look up the user in a virtual passwd file.
        {
          driver = "passwd-file";
          # Each domain has a separate passwd-file:
          args = ["username_format=%Ln" "/etc/dovecot/auth/%Ld/passwd"];
          override_fields = ["home=/var/lib/mail/home/%Ld/%Ln" "uid=mail" "gid=mail"];
        }
        # If that didn't work, maybe it's a local user.
        {
          driver = "passwd";
          override_fields = ["home=/var/lib/mail/home/comclub.org/%Ln"];
        }
      ];

      plugin.acl = "vfile:/etc/dovecot/global-acls:cache_secs=300";
      plugin.sieve = "file:~/sieve;active=~/.dovecot.sieve";
    };
  };
  security.pam.services.dovecot2 = {};
}
