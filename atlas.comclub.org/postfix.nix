{ config, lib, pkgs, ... }:
let
  sslCertDir = config.security.acme.certs."mail.isz.wtf".directory;
  isVM = config.virtualisation ? qemu;
in {
  sops.secrets."smtp_sasl_password_maps" = {};
  services.postfix = {
    enable = true;

    hostname = "atlas.comclub.org";
    domain = "comclub.org";
    origin = "comclub.org";
    destination = [
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
    recipientDelimiter = "+";

    rootAlias = "root@isz.wtf";
    sslCert = "${sslCertDir}/fullchain.pem";
    sslKey = "${sslCertDir}/key.pem";
    networks = ["127.0.0.0/8" "[::ffff:127.0.0.0]/104" "[::1]/128" "192.168.0.0/16"];
    relayHost = "mail.smtp2go.com";
    relayPort = 2525;
    mapFiles.smtp_sasl_password_maps = lib.mkIf (!isVM) config.sops.secrets."smtp_sasl_password_maps".path;
    mapFiles.virtual = pkgs.writeText "virtual" ''
      postmaster@hb-rights.org        postmaster
    '';
    mapFiles.sender_access = pkgs.writeText "sender_access" ''
      bannerrankinghigher.com REJECT UBCE
      emn-consumerpromotioncenter.com REJECT UBCE
      topspotbrands.com REJECT UBCE
      colllisted.com REJECT UBCE
    '';
    extraAliases = ""; # TODO
    config = {
      biff = false;

      # appending .domain is the MUA's job.
      append_dot_mydomain = false;

      smtpd_tls_session_cache_database = "btree:\${data_directory}/smtpd_scache";
      smtp_tls_session_cache_database = "btree:\${data_directory}/smtp_scache";

      inet_interfaces = "all";

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

      content_filter = "smtp-amavis:[127.0.0.1]:10024";
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

      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "private/auth";
    };
  };
}
