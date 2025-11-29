{ config, lib, pkgs, ... }:
let
  sslCertDir = config.security.acme.certs."mail.comclub.org".directory;
  isVM = config.virtualisation ? qemu;
in {
  sops.secrets."postfix/smtp_sasl_password_maps" = {};
  sops.secrets."postfix/user_aliases" = {};
  services.postfix = {
    enable = true;

    mapFiles.smtp_sasl_password_maps = lib.mkIf (!isVM) config.sops.secrets."postfix/smtp_sasl_password_maps".path;
    mapFiles.virtual = pkgs.writeText "virtual" ''
      postmaster@hb-rights.org        postmaster
    '';
    mapFiles.sender_access = pkgs.writeText "sender_access" ''
      bannerrankinghigher.com REJECT UBCE
      emn-consumerpromotioncenter.com REJECT UBCE
      topspotbrands.com REJECT UBCE
      colllisted.com REJECT UBCE
    '';
    aliasFiles.user_aliases = lib.mkIf (!isVM) config.sops.secrets."postfix/user_aliases".path;
    extraAliases = ''
      mailer-daemon: postmaster
      postmaster: root
      nobody: root
      root: quentin

      # Standard RFC2142 aliases
      abuse:              postmaster
      ftp:                root
      hostmaster:         root
      news:               usenet
      noc:                root
      security:           root
      usenet:             root
      uucp:               root
      webmaster:          root
      www:                webmaster
    '';
    settings.main = {
      biff = false;

      recipient_delimiter = "+";

      myhostname = "atlas.comclub.org";
      mydomain = "comclub.org";
      myorigin = "comclub.org";
      mydestination = [
        "$myhostname"
        "localhost.$mydomain"
        "localhost"
        "$mydomain"
        "mail.$mydomain"
        "www.$mydomain"
        "ftp.$mydomain"
        "comclub.dyndns.org"
        "linux.$mydomain"
        "atlas.$mydomain"
        "atlas"
      ];

      mynetworks = [
        "127.0.0.0/8"
        "[::ffff:127.0.0.0]/104"
        "[::1]/128"
        "192.168.0.0/16"
      ];

      # appending .domain is the MUA's job.
      append_dot_mydomain = false;

      smtpd_tls_session_cache_database = "btree:\${data_directory}/smtpd_scache";
      smtp_tls_session_cache_database = "btree:\${data_directory}/smtp_scache";
      smtpd_tls_chain_files = [
        "${sslCertDir}/full.pem"
      ];

      inet_interfaces = "all";

      relayhost = ["[mail.smtp2go.com]:2525"];

      smtp_sasl_auth_enable = true;
      smtp_tls_security_level = "encrypt";
      smtp_sasl_tls_security_options = "noanonymous";
      smtp_sasl_password_maps = [
        "hash:/var/lib/postfix/conf/smtp_sasl_password_maps"
      ];

      # 550 = reject, 450 = try again later
      unknown_local_recipient_reject_code = 450;

      mailbox_transport = "lmtp:unix:private/dovecot-lmtp";

      mailbox_size_limit = 0;
      virtual_mailbox_limit = 0;
      # 50 MiB
      message_size_limit = 52428800;

      smtpd_recipient_restrictions = [
        "permit_mynetworks"
        #reject_unauth_destination
        #check_policy_service inet:127.0.0.1:10023
      ];
      smtpd_sender_restrictions = [
        "check_sender_access hash:/var/lib/postfix/conf/sender_access"
      ];
      smtpd_relay_restrictions = [
        "permit_mynetworks"
        "permit_sasl_authenticated"
        "reject_unauth_destination"
        #check_policy_service inet:127.0.0.1:10023
      ];

      virtual_mailbox_domains = [
        "hb-rights.org"
      ];
      #virtual_mailbox_base = /srv/mail/vmail
      #virtual_mailbox_maps = hash:/etc/postfix/vmailbox
      virtual_transport = "$mailbox_transport";
      #virtual_minimum_uid = 100
      #virtual_uid_maps = static:60000
      #virtual_gid_maps = static:8
      virtual_alias_maps = ["hash:/var/lib/postfix/conf/virtual"];

      # Merged with extraAliases
      alias_maps = lib.mkIf (!isVM) ["hash:/var/lib/postfix/conf/user_aliases"];

      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "private/auth";
    };
    settings.master.submission = {
      type = "inet";
      private = false;
      command = "smtpd";
      args = [
        "-o" "smtpd_tls_security_level=encrypt"
        "-o" "smtpd_sasl_auth_enable=yes"
        "-o" "smtpd_client_restrictions=permit_sasl_authenticated,reject"
        "-o" "milter_macro_daemon_name=ORIGINATING"
      ];
    };
  };
  services.rspamd = {
    enable = true;
    postfix.enable = true;
    locals."milter_headers.conf".text = ''
      extended_spam_headers = true;
      use = ["x-spam-status"];
    '';
    # TODO: Enable DKIM signing?
    locals."dkim_signing.conf".text = ''
      enabled = false;
    '';
    locals."redis.conf".text = ''
      servers = "${config.services.redis.servers.rspamd.unixSocket}";
    '';
  };
  services.redis.servers.rspamd = {
    enable = true;
    # 0 disables listening to TCP ports and will only use unix sockets. Default
    # unix socket path is /run/redis-${name}/redis.sock thus
    # /run/redis-rspamd/redis.sock here.
    port = 0;
    inherit (config.services.rspamd) user;
  };
}
