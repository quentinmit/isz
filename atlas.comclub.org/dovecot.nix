{ config, pkgs, lib, ... }:
let
  sslCertDir = config.security.acme.certs."mail.comclub.org".directory;
in {
  services.nginx.virtualHosts."mail.comclub.org".enableACME = true;
  users.users.mail = {
    group = "mail";
    isSystemUser = true;
  };
  users.groups.mail = {};

  # Make sieve plugin available
  environment.systemPackages = with pkgs; [ dovecot_pigeonhole cyrus-imapd ];

  services.dovecot2 = {
    enable = true;

    package = pkgs.dovecot; # Dovecot 2.4

    enablePAM = false; # Handled below

    sieve.pipeBins = map lib.getExe [
      (pkgs.writeShellScriptBin "learn-ham.sh" "exec ${pkgs.rspamd}/bin/rspamc learn_ham")
      (pkgs.writeShellScriptBin "learn-spam.sh" "exec ${pkgs.rspamd}/bin/rspamc learn_spam")
    ];

    settings = {
      dovecot_config_version = "2.4.2";
      dovecot_storage_version = "2.4.0";

      ssl_server = {
        cert_file = "${sslCertDir}/cert.pem";
        key_file = "${sslCertDir}/key.pem";
        ca_file = "${sslCertDir}/chain.pem";
      };

      protocols.imap = true;
      protocols.lmtp = true;

      auth_mechanisms = ["plain" "login"];
      auth_verbose = true;
      log_debug = "category=auth";
      #mail_debug = true;

      mdbox_rotate_size = "64M";

      mail_driver = "mdbox";
      mail_path = "~/mdbox";
      mail_privileged_group = "mail";

      "namespace inbox" = {
        inbox = true;
      };
      "namespace shared" = {
        type = "shared";
        prefix = "shared/$user/";
        mail_driver = "mdbox";
        mail_path = "%{owner_home}/Maildir";
        subscriptions = false;
        list = "children";
      };
      "namespace ns1" = {
        separator = "/";
        prefix = "mail/";
        hidden = true;
        list = false;
        alias_for = "";
      };
      "namespace ns2" = {
        separator = "/";
        prefix = "~/mail/";
        hidden = true;
        list = false;
        alias_for = "";
      };
      "namespace ns3" = {
        separator = "/";
        prefix = "~%{user}/mail/";
        hidden = true;
        list = false;
        alias_for = "";
      };

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
      auth_username_format = ''%{user | lower | regexp("@comclub\\.org$", "")}'';
      # Virtual domains
      "passdb 01-virtual" = {
        driver = "passwd-file";
        # Each domain has a separate passwd-file:
        passwd_file_path = "/etc/dovecot/auth/%{user | domain | lower}/passwd";
        auth_allow_weak_schemes = true;
        default_password_scheme = "crypt";
        auth_username_format = "%{user | username | lower}";
      };
      "passdb 02-pam" = {
        driver = "pam";
        pam_service_name = "dovecot2";
      };
      "userdb 01-virtual" = {
        # First try to look up the user in a virtual passwd file.
        driver = "passwd-file";
        # Each domain has a separate passwd-file:
        passwd_file_path = "/etc/dovecot/auth/%{user | domain | lower}/passwd";
        auth_username_format = "%{user | username | lower}";
        fields.home = "/var/lib/mail/home/%{user | domain | lower}/%{user | username | lower}";
        fields.uid = "mail";
        fields.gid = "mail";
      };
      # If that didn't work, maybe it's a local user.
      "userdb 02-local" = {
        driver = "passwd";
        fields.home = "/var/lib/mail/home/comclub.org/%{user | username | lower}";
      };

      mail_plugins.acl = true;
      acl_driver = "vfile";
      "protocol lmtp".mail_plugins.sieve = true;
      "protocol imap".mail_plugins.imap_sieve = true;
      sieve_global_extensions = {
        enotify = true;
        imap4flags = true;
        "vnd.dovecot.filter" = true;
      };
      "sieve_script personal" = {
        active_path = "~/.dovecot.sieve";
        driver = "file";
        path = "~/sieve";
      };
    };
  };
  security.pam.services.dovecot2 = {};
}
