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
        remote 206.123.152.245 15021
        <ca>
        -----BEGIN CERTIFICATE-----
        MIIE6DCCA9CgAwIBAgIJAMjXFoeo5uSlMA0GCSqGSIb3DQEBCwUAMIGoMQswCQYD
        VQQGEwJISzEQMA4GA1UECBMHQ2VudHJhbDELMAkGA1UEBxMCSEsxGDAWBgNVBAoT
        D1NlY3VyZS1TZXJ2ZXJDQTELMAkGA1UECxMCSVQxGDAWBgNVBAMTD1NlY3VyZS1T
        ZXJ2ZXJDQTEYMBYGA1UEKRMPU2VjdXJlLVNlcnZlckNBMR8wHQYJKoZIhvcNAQkB
        FhBtYWlsQGhvc3QuZG9tYWluMB4XDTE2MDExNTE1MzQwOVoXDTI2MDExMjE1MzQw
        OVowgagxCzAJBgNVBAYTAkhLMRAwDgYDVQQIEwdDZW50cmFsMQswCQYDVQQHEwJI
        SzEYMBYGA1UEChMPU2VjdXJlLVNlcnZlckNBMQswCQYDVQQLEwJJVDEYMBYGA1UE
        AxMPU2VjdXJlLVNlcnZlckNBMRgwFgYDVQQpEw9TZWN1cmUtU2VydmVyQ0ExHzAd
        BgkqhkiG9w0BCQEWEG1haWxAaG9zdC5kb21haW4wggEiMA0GCSqGSIb3DQEBAQUA
        A4IBDwAwggEKAoIBAQDluufhyLlyvXzPUL16kAWAdivl1roQv3QHbuRshyKacf/1
        Er1JqEbtW3Mx9Fvr/u27qU2W8lQI6DaJhU2BfijPe/KHkib55mvHzIVvoexxya26
        nk79F2c+d9PnuuMdThWQO3El5a/i2AASnM7T7piIBT2WRZW2i8RbfJaTT7G7LP7O
        pMKIV1qyBg/cWoO7cIWQW4jmzqrNryIkF0AzStLN1DxvnQZwgXBGv0CwuAkfQuNS
        Lu0PQgPp0PhdukNZFllv5D29IhPr0Z+kwPtrAgPQo+lHlOBHBMUpDT4XChTPeAvM
        aUSBsqmonAE8UUHEabWrqYN/kWNHCNkYXMkiVmK1AgMBAAGjggERMIIBDTAdBgNV
        HQ4EFgQU456ijsFrYnzHBShLAPpOUqQ+Z2cwgd0GA1UdIwSB1TCB0oAU456ijsFr
        YnzHBShLAPpOUqQ+Z2ehga6kgaswgagxCzAJBgNVBAYTAkhLMRAwDgYDVQQIEwdD
        ZW50cmFsMQswCQYDVQQHEwJISzEYMBYGA1UEChMPU2VjdXJlLVNlcnZlckNBMQsw
        CQYDVQQLEwJJVDEYMBYGA1UEAxMPU2VjdXJlLVNlcnZlckNBMRgwFgYDVQQpEw9T
        ZWN1cmUtU2VydmVyQ0ExHzAdBgkqhkiG9w0BCQEWEG1haWxAaG9zdC5kb21haW6C
        CQDI1xaHqObkpTAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQCvga2H
        MwOtUxWH/inL2qk24KX2pxLg939JNhqoyNrUpbDHag5xPQYXUmUpKrNJZ0z+o/Zn
        NUPHydTSXE7Z7E45J0GDN5E7g4pakndKnDLSjp03NgGsCGW+cXnz6UBPM5FStFvG
        dDeModeSUyoS9fjk+mYROvmiy5EiVDP91sKGcPLR7Ym0M7zl2aaqV7bb98HmMoBO
        xpeZQinof67nKrCsgz/xjktWFgcmPl4/PQSsmqQD0fTtWxGuRX+FzwvF2OCMCAJg
        p1RqJNlk2g50/kBIoJVPPCfjDFeDU5zGaWGSQ9+z1L6/z7VXdjUiHL0ouOcHwbiS
        4ZjTr9nMn6WdAHU2
        -----END CERTIFICATE-----
        </ca>
        <cert>
        -----BEGIN CERTIFICATE-----
        MIIEnzCCA4egAwIBAgIBAzANBgkqhkiG9w0BAQsFADCBqDELMAkGA1UEBhMCSEsx
        EDAOBgNVBAgTB0NlbnRyYWwxCzAJBgNVBAcTAkhLMRgwFgYDVQQKEw9TZWN1cmUt
        U2VydmVyQ0ExCzAJBgNVBAsTAklUMRgwFgYDVQQDEw9TZWN1cmUtU2VydmVyQ0Ex
        GDAWBgNVBCkTD1NlY3VyZS1TZXJ2ZXJDQTEfMB0GCSqGSIb3DQEJARYQbWFpbEBo
        b3N0LmRvbWFpbjAeFw0xNjAxMTUxNjE1MzhaFw0yNjAxMTIxNjE1MzhaMIGdMQsw
        CQYDVQQGEwJISzEQMA4GA1UECBMHQ2VudHJhbDELMAkGA1UEBxMCSEsxFjAUBgNV
        BAoTDVNlY3VyZS1DbGllbnQxCzAJBgNVBAsTAklUMRYwFAYDVQQDEw1TZWN1cmUt
        Q2xpZW50MREwDwYDVQQpEwhjaGFuZ2VtZTEfMB0GCSqGSIb3DQEJARYQbWFpbEBo
        b3N0LmRvbWFpbjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAxsnyn4v6xxDP
        nuDaYS0b9M1N8nxgg7OBPBlK+FWRxdTQ8yxt5U5CZGm7riVp7fya2J2iPZIgmHQE
        v/KbxztsHAVlYSfYYlalrnhEL3bDP2tY+N43AwB1k5BrPq2s1pPLT2XG951drDKG
        4PUuFHUP1sHzW5oQlfVCmxgIMAP8OYkCAwEAAaOCAV8wggFbMAkGA1UdEwQCMAAw
        LQYJYIZIAYb4QgENBCAWHkVhc3ktUlNBIEdlbmVyYXRlZCBDZXJ0aWZpY2F0ZTAd
        BgNVHQ4EFgQU9MwUnUDbQKKZKjoeieD2OD5NlAEwgd0GA1UdIwSB1TCB0oAU456i
        jsFrYnzHBShLAPpOUqQ+Z2ehga6kgaswgagxCzAJBgNVBAYTAkhLMRAwDgYDVQQI
        EwdDZW50cmFsMQswCQYDVQQHEwJISzEYMBYGA1UEChMPU2VjdXJlLVNlcnZlckNB
        MQswCQYDVQQLEwJJVDEYMBYGA1UEAxMPU2VjdXJlLVNlcnZlckNBMRgwFgYDVQQp
        Ew9TZWN1cmUtU2VydmVyQ0ExHzAdBgkqhkiG9w0BCQEWEG1haWxAaG9zdC5kb21h
        aW6CCQDI1xaHqObkpTATBgNVHSUEDDAKBggrBgEFBQcDAjALBgNVHQ8EBAMCB4Aw
        DQYJKoZIhvcNAQELBQADggEBAFyFo2VUX/UFixsdPdK9/Yt6mkCWc+XS1xbapGXX
        b9U1d+h1iBCIV9odUHgNCXWpz1hR5Uu/OCzaZ0asLE4IFMZlQmJs8sMT0c1tfPPG
        W45vxbL0lhqnQ8PNcBH7huNK7VFjUh4szXRKmaQPaM4S91R3L4CaNfVeHfAg7mN2
        m9Zn5Gto1Q1/CFMGKu2hxwGEw5p+X1czBWEvg/O09ckx/ggkkI1NcZsNiYQ+6Pz8
        DdGGX3+05YwLZu94+O6iIMrzxl/il0eK83g3YPbsOrASARvw6w/8sOnJCK5eOacl
        21oww875KisnYdWjHB1FiI+VzQ1/gyoDsL5kPTJVuu2CoG8=
        -----END CERTIFICATE-----
        </cert>
      '';
    };
  };
}
