{ config, lib, pkgs, ... }:

{
  sops.secrets."smtp_sasl_password_maps" = {};
  services.postfix = {
    enable = true;
    rootAlias = "root@isz.wtf";
    mapFiles.smtp_sasl_password_maps = config.sops.secrets."smtp_sasl_password_maps".path;
    settings.main = rec {
      myorigin = "isz.wtf";
      mynetworks = ["127.0.0.0/8" "[::ffff:127.0.0.0]/104" "[::1]/128"];
      relayhost = ["mail.smtp2go.com:2525"];
      # smtpd_banner = $myhostname ESMTP
      # UNNEEDED? biff = no
      # DEFAULT append_dot_mydomain = no
      # STOCK readme_directory = no
      # STOCK compatibility_level = 2
      # UNNEEDED? myhostname = workshop.isz.wtf
      # DONE? alias_maps = hash:/etc/aliases
      # UNNEEDED mydestination = workshop.isz.wtf, localhost.isz.wtf, localhost
      mailbox_size_limit = "0";
      recipient_delimiter = "+";
      # DEFAULT inet_interfaces = all
      # STOCK html_directory = no
      enable_long_queue_ids = true;

      smtp_sasl_auth_enable = true;
      smtp_sasl_tls_security_options = "noanonymous";
      smtp_sasl_password_maps = [
        "hash:/var/lib/postfix/conf/smtp_sasl_password_maps"
      ];

      tls_preempt_cipherlist = true;
      tls_ssl_options = ["NO_COMPRESSION"];

      # smtpd_use_tls = yes
      # smtpd_tls_security_level = may
      # smtpd_tls_cert_file = /etc/pki/realms/domain/default.crt
      # smtpd_tls_key_file = /etc/pki/realms/domain/default.key
      # smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
      # smtpd_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
      # smtpd_tls_loglevel = 1
      # smtpd_tls_auth_only = yes
      # smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, TLSv1.1, TLSv1.2
      # smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, TLSv1.1, TLSv1.2
      # smtpd_tls_ciphers = high
      # smtpd_tls_mandatory_ciphers = high
      # smtpd_tls_exclude_ciphers = aNULL, RC4, MD5, DES, 3DES, RSA, SHA
      # smtpd_tls_eecdh_grade = ultra
      # smtpd_tls_received_header = yes

      smtp_tls_security_level = "encrypt";
      smtp_tls_session_cache_database = "btree:\${data_directory}/smtp_scache";
      # STOCK smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
      smtp_tls_loglevel = "1";
      smtp_tls_protocols = ["!SSLv2" "!SSLv3" "!TLSv1" "TLSv1.1" "TLSv1.2"];
      smtp_tls_mandatory_protocols = ["!SSLv2" "!SSLv3" "!TLSv1" "TLSv1.1" "TLSv1.2"];
      smtp_tls_ciphers = "high";
      smtp_tls_mandatory_ciphers = "high";
      smtp_tls_exclude_ciphers = ["aNULL" "RC4" "MD5" "DES" "3DES" "RSA" "SHA"];
      smtp_tls_note_starttls_offer = true;

      lmtp_tls_security_level = "may";
      lmtp_tls_CAfile = config.security.pki.caBundle;
      lmtp_tls_session_cache_database = "btree:\${data_directory}/lmtp_scache";
      lmtp_tls_loglevel = "1";
      lmtp_tls_protocols = smtp_tls_protocols;
      lmtp_tls_mandatory_protocols = smtp_tls_mandatory_protocols;
      lmtp_tls_ciphers = smtp_tls_ciphers;
      lmtp_tls_mandatory_ciphers = smtp_tls_mandatory_ciphers;
      lmtp_tls_exclude_ciphers = smtp_tls_exclude_ciphers;
      lmtp_tls_note_starttls_offer = true;

      smtpd_helo_required = true;
      strict_rfc821_envelopes = true;
      smtpd_reject_unlisted_sender = true;
      disable_vrfy_command = true;

      # DEFAULT smtpd_client_restrictions =
      smtpd_helo_restrictions = [
        "permit_mynetworks"
        "reject_invalid_helo_hostname"
        "reject_non_fqdn_helo_hostname"
        "reject_unknown_helo_hostname"
      ];

      smtpd_sender_restrictions = [
        "reject_non_fqdn_sender"
        "reject_unknown_sender_domain"
        "permit_mynetworks"
      ];

      smtpd_discard_ehlo_keywords = ["dsn" "etrn"];
      smtpd_relay_restrictions = [
        "permit_mynetworks"
        "permit_sasl_authenticated"
        "defer_unauth_destination"
      ];

      smtpd_recipient_restrictions = [
        "reject_non_fqdn_recipient"
        "reject_unknown_recipient_domain"
      ];

      smtpd_data_restrictions = [
        "reject_unauth_pipelining"
        "reject_multi_recipient_bounce"
      ];
    };
  };
}
