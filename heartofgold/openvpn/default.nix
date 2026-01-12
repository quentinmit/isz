{ lib, pkgs, config, options, ... }:
let
  vpnc-script-container = pkgs.callPackage ./vpnc-script-container.nix {};
  vpnc-script-sshd = pkgs.callPackage ./vpnc-script-sshd.nix {};
in {
  config = {
    sops.secrets = {
      "purevpn/keys" = {};
      "purevpn/auth" = {};
    };
    home-manager.sharedModules = [{
      programs.starship.settings = {
        env_var.debian_chroot = {
          variable = "debian_chroot";
        };
      };
      programs.bash.initExtra = ''
        if [ -n "$SSH_CONNECTION" ] && [[ "$SSH_CONNECTION" == *fec0::1* ]]; then
          export debian_chroot="vpn"
        fi
      '';
    }];
    systemd.services.openvpn-purevpn-DE = rec {
      requires = [
        "home-quentin-hog\\x2ddata.mount"
        "container@rtorrent.service"
      ];
      after = requires;
      restartIfChanged = false;
      serviceConfig = {
        ProtectSystem = "no";
        ProtectHome = "no";
        CapabilityBoundingSet = "~";
        LimitNPROC = "infinity";
        KillMode = "process";
      };
    };
    services.openvpn.servers.purevpn-DE = {
      autoStart = false;
      up = ''
        env | sort >&2
        containerName=rtorrent exec ${vpnc-script-container}/bin/vpnc-script-container
      '';
#       up = ''
#         # cmd tun_dev tun_mtu link_mtu ifconfig_local_ip ifconfig_remote_ip [ init | restart ]
#
#         export TUNDEV=$1
#         export INTERNAL_IP4_MTU=$2
#         export reason=connect
#         export INTERNAL_IP4_ADDRESS=$ifconfig_local
#         export INTERNAL_IP4_GATEWAY=$ifconfig_remote
#
#         declare -a dns
#         for var in ''${!foreign_option_*}; do
#           set -- ''${!var}
#           if [ $1 = "dhcp-option" ]; then
#             case $2 in
#               DNS)
#                 dns+=($3)
#                 ;;
#             esac
#           fi
#         done
#
#
#         export INTERNAL_IP4_DNS="''${dns[@]}"
#         echo client.up "$@"
#
#         ${vpnc-script-sshd}/bin/vpnc-script-sshd
#       '';
#       down = ''
#         export TUNDEV=$1
#         export reason=disconnect
#         ${vpnc-script-sshd}/bin/vpnc-script-sshd
#       '';
      config = ''
        client
        verb 4
        config ${config.sops.secrets."purevpn/keys".path}
        dev tun
        auth-user-pass ${config.sops.secrets."purevpn/auth".path}
        persist-key
        persist-tun
        nobind
        key-direction 1
        remote-cert-tls server
        cipher AES-256-CBC
        # route-delay 0
        # route 0.0.0.0 0.0.0.0
        route-noexec
        ifconfig-noexec
        script-security 2
        explicit-exit-notify 2
        proto udp
        remote 185.232.23.111 15021
        <ca>
        -----BEGIN CERTIFICATE-----
        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
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        MIIGBzCCA++gAwIBAgIULjehn3oKy7VgPWVqBLqG3RcBw6AwDQYJKoZIhvcNAQEL
        BQAwgZIxCzAJBgNVBAYTAlZHMRAwDgYDVQQIEwdUb3J0b2xhMREwDwYDVQQHEwhS
        b2FkdG93bjEXMBUGA1UEChMOU2VjdXJlLVNlcnZlclExCzAJBgNVBAsTAklUMRcw
        FQYDVQQDEw5TZWN1cmUtU2VydmVyUTEfMB0GCSqGSIb3DQEJARYQbWFpbEBob3N0
        LmRvbWFpbjAeFw0yMjA0MjAwNjUxNTFaFw0zMjA0MTcwNjUxNTFaMIGSMQswCQYD
        VQQGEwJWRzEQMA4GA1UECBMHVG9ydG9sYTERMA8GA1UEBxMIUm9hZHRvd24xFzAV
        BgNVBAoTDlNlY3VyZS1TZXJ2ZXJRMQswCQYDVQQLEwJJVDEXMBUGA1UEAxMOU2Vj
        dXJlLVNlcnZlclExHzAdBgkqhkiG9w0BCQEWEG1haWxAaG9zdC5kb21haW4wggIi
        MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDYBqR63rzysa2c/1YTn811McVX
        AvkqV1smE3jLv1TP4VW/nD67Sb43iKc/lhkbgXV89PFQt6BswK8BPC5TzXi/kTFJ
        txkN79L9insG+DFiz/NvKRWxdAbKJZtv7c2eBLYOAflYcI/HwkBJa01uvPtGtCKO
        qfhwB120Kwq1gxr95DTU4OtPm8PRfUookiCCFb7qip6twABfcC5lntI3UBN1CQfi
        CtgdY32+7doeFURH+jY9JS4Ots78LKVN8GiMUxJosSHGxw2+/ERwD6IiJO5AeRIg
        BSSa2GW3WNlQ4qHTq0obVDoK3+xMAbhbRjVYriynYPB70mN82lWN1chXaiDeW/l0
        g7DU/EJKCAkYLlMr2hI1kMTu9AYHKUH/NsEC1Z8Nf6GCxi9zlOcuANNNxxioDeUE
        ANoMCRRb1hQDx83udxSLTbR8qCO2+G2EJp/L9M/efGn6L7U7qvKxzua8ZbLAWKMw
        FtqVRD0+oZPN6rEVFrOx9byz6DFA6vKa76dpdLbISnOrqyQVxkZMhBuL/fFbHyLW
        xD9QN9dnVx8q3W8fhJXdDln4oMOzyMm/0K0iar7GLjGKQ3Zmz9qJ1lWCdyA800Ub
        J5eeD4SXmB2eYZnQxW8MGmHygz0mslBzhN7mB+7sxMIiLFiCc6SqYu6ONDOVEe0T
        +H0pka1yN6o/9TLJtwIDAQABo1MwUTAdBgNVHQ4EFgQUsC/fyv2nQRAEg6aH2OQh
        89HR5uIwHwYDVR0jBBgwFoAUsC/fyv2nQRAEg6aH2OQh89HR5uIwDwYDVR0TAQH/
        BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAnklSAVjZLlyy0iaM4g29+t87RDUf
        MAEkJEq+qq23Ovrvw9XPr8xfp3rhPgY/12EQofwWuToIQeRawZJ9ZKq3+ELpOZAE
        GkuA22vQdYaulY8suUXWuD4hFCvsKWA/jASrEY29l54r0yCcElrN5upqm7BoRbHY
        FieO0ieBmGaLoxAqjZc99KkO4QELXtn7OMsXmXTUwlA8m9acTDKmpl6cVs2Cq/Fo
        z6NbbWvCb65q1HZSmfkXB8mCZnLF+1wERpQeTpnA0cNT4RUGTe2PQsTXOBgASEab
        O7AFDkg2H7YgmfBwVZKwHZWo72ggSdHUygKOT1+v9Xt1oFg3k6l/GiyVsvCSzN0G
        /7VzDJuAIRtDIs/daDhXxyHaAqbKQ8VDHuLBxMTYQQnndt2D6J7XxtQ2F/iWqDZw
        +l8gukFwrgOMgq7ZYYeOOxKx20zbBAUELYtNF2KaLJjKiZJmQd/1OjuKYexggFWB
        C2f1OiDzxzrqAocSnGllVPmmh0ALJCi8eMT5lt9sfZq5hWPYnwDYeVQ1A/5l7x+V
        bcqeQAJCYh/RIy60Tp7QYeliECJDkowDGtIcz+v97FkcTsL+8r+xbM3z3f3oQSYT
        JEBPe8DnGAyveCuwo0trH4kGLiAiqS+2mR0pMhDFIXXgL9EF/S7KkHT9Wfn6FE0j
        Ggjbe2PZOrN9Ts0=
        -----END CERTIFICATE-----
        </ca>
        <cert>
        -----BEGIN CERTIFICATE-----
        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
        -----END CERTIFICATE-----
        </cert>
      '';
    };
  };
}
