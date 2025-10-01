{ config, ... }:
let
  sslCertDir = config.security.acme.certs."mail.comclub.org".directory;
in {
  services.nginx.virtualHosts."mail.comclub.org".enableACME = true;
  users.groups.mail = {};
  services.dovecot2 = {
    enable = true;

    sslServerCert = "${sslCertDir}/cert.pem";
    sslServerKey = "${sslCertDir}/key.pem";
    sslCACert = "${sslCertDir}/chain.pem";

    enableLmtp = true;
    enablePAM = false; # Handled below

    mailLocation = "mdbox:/var/lib/dovecot/mdbox/%d/%n";

    mailPlugins.globally.enable = [
      "acl"
    ];

    mailPlugins.perProtocol.lda.enable = [
      "sieve"
    ];

    extraConfig = ''
      auth_mechanisms = plain login
      auth_verbose = yes

      namespace inbox {
        inbox = yes
      }
      namespace {
        type = shared
        separator = /
        prefix = shared/%%n/
        location = mdbox:/var/lib/dovecot/mdbox/%%n
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
      auth_username_format = %Lu
      auth_debug = yes
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
      passdb {
        driver = static
        args = user=%u noauthenticate
        skip = authenticated
        username_filter = *@comclub.org
      }
      userdb {
        driver = passwd
      }
      passdb {
        driver = pam
        args = dovecot2
      }
    '';
    pluginSettings = {
      acl = "vfile:/etc/dovecot/global-acls:cache_secs=300";
      sieve = "file:~/sieve;active=~/.dovecot.sieve";
    };
  };
  security.pam.services.dovecot2 = {};
}
