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

    sslServerCert = "${sslCertDir}/cert.pem";
    sslServerKey = "${sslCertDir}/key.pem";
    sslCACert = "${sslCertDir}/chain.pem";

    enableLmtp = true;
    enablePAM = false; # Handled below

    mailLocation = "mdbox:~/mdbox";

    mailPlugins.globally.enable = [
      "acl"
    ];

    mailPlugins.perProtocol.lda.enable = [
      "sieve"
    ];

    extraConfig = ''
      auth_mechanisms = plain login
      auth_verbose = yes
      auth_debug = yes
      #mail_debug = yes

      mdbox_rotate_size = 64M

      namespace inbox {
        inbox = yes
      }
      namespace {
        type = shared
        separator = /
        prefix = shared/%%n/
        location = mdbox:%%h/mdbox
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
      auth_username_format = %{if;%Ld;eq;comclub.org;%Ln;%Lu}
      # First try to look up the user in a virtual passwd file.
      passdb {
        driver = passwd-file
        # Each domain has a separate passwd-file:
        args = scheme=plain-md5 username_format=%Ln /etc/dovecot/auth/%Ld/passwd
      }
      userdb {
        driver = passwd-file
        # Each domain has a separate passwd-file:
        args = username_format=%Ln /etc/dovecot/auth/%Ld/passwd
        override_fields = home=/var/lib/mail/home/%Ld/%Ln uid=mail gid=mail
      }
      # If that didn't work, maybe it's a local user.
      userdb {
        driver = passwd
        override_fields = home=/var/lib/mail/home/comclub.org/%Ln
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
