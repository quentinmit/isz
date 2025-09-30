{ config, ... }:
let
  sslCertDir = config.security.acme.certs."mail.isz.wtf".directory;
in {
  services.nginx.virtualHosts."mail.isz.wtf".enableACME = true;
  services.dovecot2 = {
    enable = true;

    sslServerCert = "${sslCertDir}/cert.pem";
    sslServerKey = "${sslCertDir}/key.pem";
    sslCACert = "${sslCertDir}/chain.pem";

    enableLmtp = true;

    mailLocation = "mdbox:/var/lib/dovecot/mdbox/%u";

    mailPlugins.globally.enable = [
      "acl"
    ];

    mailPlugins.perProtocol.lda.enable = [
      "sieve"
    ];

    extraConfig = ''
      auth_username_format = %Ln
      auth_mechanisms = plain login
      auth_verbose = yes

      namespace inbox {
        inbox = yes
      }
      namespace {
        type = shared
        separator = /
        prefix = shared/%%u/
        location = mdbox:/var/lib/dovecot/mdbox/%%u
        subscriptions = no
        list = children
      }
      namespace {
        separator = /
        prefix = mail/
        hidden = yes
        list = no
        alias_for =
      }
      namespace {
        separator = /
        prefix = ~/mail/
        hidden = yes
        list = no
        alias_for =
      }
      namespace {
        separator = /
        prefix = ~%u/mail/
        hidden = yes
        list = no
        alias_for =
      }
      mail_privileged_group = mail
      service lmtp {
        unix_listener /var/lib/postfix/queue/private/dovecot-lmtp {
          mode = 0660
          user = postfix
          group = postfix
        }
      }
      service auth {
        unix_listener /var/lib/postfix/queue/private/auth {
          mode = 0660
          user = postfix
          group = postfix
        }
      }
      # Virtual domains
      passdb {
        driver = passwd-file
        # Each domain has a separate passwd-file:
        args = scheme=plain-md5 username_format=%n /etc/dovecot/auth/%d/passwd
      }
      userdb {
        driver = passwd-file
        # Each domain has a separate passwd-file:
        args = username_format=%n /etc/dovecot/auth/%d/passwd
      }
    '';
    pluginSettings = {
      acl = "vfile:/etc/dovecot/global-acls:cache_secs=300";
      sieve = "file:~/sieve;active=~/.dovecot.sieve";
    };
  };
}
